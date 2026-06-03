#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef REAL_LIBEVDI
#error "REAL_LIBEVDI must point at the real libevdi.so"
#endif

#define EDID_ENV "DEVSHOP_DISPLAYLINK_EVDI_EDID"

struct evdi_lib_version {
  int version_major;
  int version_minor;
  int version_patchlevel;
};

struct evdi_device_context;
typedef struct evdi_device_context *evdi_handle;
typedef int evdi_selectable;

enum evdi_device_status {
  AVAILABLE,
  UNRECOGNIZED,
  NOT_PRESENT
};

struct evdi_rect {
  int x1, y1, x2, y2;
};

struct evdi_mode {
  int width;
  int height;
  int refresh_rate;
  int bits_per_pixel;
  unsigned int pixel_format;
};

struct evdi_buffer {
  int id;
  void *buffer;
  int width;
  int height;
  int stride;
  struct evdi_rect *rects;
  int rect_count;
};

struct evdi_cursor_set {
  int32_t hot_x;
  int32_t hot_y;
  uint32_t width;
  uint32_t height;
  uint8_t enabled;
  uint32_t buffer_length;
  uint32_t *buffer;
  uint32_t pixel_format;
  uint32_t stride;
};

struct evdi_cursor_move {
  int32_t x;
  int32_t y;
};

struct evdi_ddcci_data {
  uint16_t address;
  uint16_t flags;
  uint32_t buffer_length;
  uint8_t *buffer;
};

struct evdi_event_context {
  void (*dpms_handler)(int dpms_mode, void *user_data);
  void (*mode_changed_handler)(struct evdi_mode mode, void *user_data);
  void (*update_ready_handler)(int buffer_to_be_updated, void *user_data);
  void (*crtc_state_handler)(int state, void *user_data);
  void (*cursor_set_handler)(struct evdi_cursor_set cursor_set, void *user_data);
  void (*cursor_move_handler)(struct evdi_cursor_move cursor_move, void *user_data);
  void (*ddcci_data_handler)(struct evdi_ddcci_data ddcci_data, void *user_data);
  void *user_data;
};

struct evdi_logging {
  void (*function)(void *user_data, const char *fmt, ...);
  void *user_data;
};

const int command_length = 50;
const int name_length = 30;
struct evdi_logging g_evdi_logging = {0};

static void *real_libevdi;
static unsigned char *override_edid;
static unsigned int override_edid_length;
static int override_checked;
static int replacement_logged;

static void load_real_libevdi(void) {
  if (real_libevdi)
    return;

  real_libevdi = dlopen(REAL_LIBEVDI, RTLD_NOW | RTLD_LOCAL);
  if (!real_libevdi) {
    fprintf(stderr, "displaylink-evdi-edid-shim: failed to load %s: %s\n",
            REAL_LIBEVDI, dlerror());
    abort();
  }
}

static void *real_symbol(const char *name) {
  void *symbol;

  load_real_libevdi();
  dlerror();
  symbol = dlsym(real_libevdi, name);
  if (!symbol) {
    fprintf(stderr,
            "displaylink-evdi-edid-shim: missing libevdi symbol %s: %s\n",
            name, dlerror());
    abort();
  }
  return symbol;
}

static void load_override_edid(void) {
  const char *path;
  FILE *file;
  long size;
  unsigned char *buffer;

  if (override_checked)
    return;
  override_checked = 1;

  path = getenv(EDID_ENV);
  if (!path || !*path)
    return;

  file = fopen(path, "rb");
  if (!file) {
    fprintf(stderr, "displaylink-evdi-edid-shim: unable to open %s=%s: %s\n",
            EDID_ENV, path, strerror(errno));
    return;
  }

  if (fseek(file, 0, SEEK_END) != 0) {
    fprintf(stderr,
            "displaylink-evdi-edid-shim: unable to seek EDID file %s: %s\n",
            path, strerror(errno));
    fclose(file);
    return;
  }

  size = ftell(file);
  if (size < 128 || size > 32640 || size % 128 != 0) {
    fprintf(stderr,
            "displaylink-evdi-edid-shim: refusing EDID file %s with invalid "
            "size %ld\n",
            path, size);
    fclose(file);
    return;
  }

  if (fseek(file, 0, SEEK_SET) != 0) {
    fprintf(stderr,
            "displaylink-evdi-edid-shim: unable to rewind EDID file %s: %s\n",
            path, strerror(errno));
    fclose(file);
    return;
  }

  buffer = malloc((size_t)size);
  if (!buffer) {
    fprintf(stderr,
            "displaylink-evdi-edid-shim: unable to allocate %ld bytes for EDID "
            "file %s\n",
            size, path);
    fclose(file);
    return;
  }

  if (fread(buffer, 1, (size_t)size, file) != (size_t)size) {
    fprintf(stderr, "displaylink-evdi-edid-shim: unable to read EDID file %s\n",
            path);
    free(buffer);
    fclose(file);
    return;
  }

  fclose(file);
  override_edid = buffer;
  override_edid_length = (unsigned int)size;
  fprintf(stderr,
          "displaylink-evdi-edid-shim: loaded EDID override from %s (%u "
          "bytes)\n",
          path, override_edid_length);
}

static const unsigned char *
edid_for_connect(const unsigned char *edid, const unsigned int edid_length,
                 unsigned int *selected_length) {
  load_override_edid();
  if (override_edid && override_edid_length) {
    if (!replacement_logged) {
      fprintf(stderr,
              "displaylink-evdi-edid-shim: replacing DisplayLinkManager EDID "
              "length %u with override length %u\n",
              edid_length, override_edid_length);
      replacement_logged = 1;
    }
    *selected_length = override_edid_length;
    return override_edid;
  }

  *selected_length = edid_length;
  return edid;
}

enum evdi_device_status evdi_check_device(int device) {
  typedef enum evdi_device_status (*real_fn)(int);
  return ((real_fn)real_symbol("evdi_check_device"))(device);
}

evdi_handle evdi_open(int device) {
  typedef evdi_handle (*real_fn)(int);
  return ((real_fn)real_symbol("evdi_open"))(device);
}

int evdi_add_device(void) {
  typedef int (*real_fn)(void);
  return ((real_fn)real_symbol("evdi_add_device"))();
}

evdi_handle evdi_open_attached_to(const char *sysfs_parent_device) {
  typedef evdi_handle (*real_fn)(const char *);
  return ((real_fn)real_symbol("evdi_open_attached_to"))(sysfs_parent_device);
}

evdi_handle evdi_open_attached_to_fixed(const char *sysfs_parent_device,
                                        size_t length) {
  typedef evdi_handle (*real_fn)(const char *, size_t);
  return ((real_fn)real_symbol("evdi_open_attached_to_fixed"))(
      sysfs_parent_device, length);
}

void evdi_close(evdi_handle handle) {
  typedef void (*real_fn)(evdi_handle);
  ((real_fn)real_symbol("evdi_close"))(handle);
}

void evdi_connect(evdi_handle handle, const unsigned char *edid,
                  const unsigned int edid_length,
                  const uint32_t sku_area_limit) {
  typedef void (*real_fn)(evdi_handle, const unsigned char *,
                          const unsigned int, const uint32_t);
  unsigned int selected_length;
  const unsigned char *selected_edid =
      edid_for_connect(edid, edid_length, &selected_length);
  ((real_fn)real_symbol("evdi_connect"))(handle, selected_edid,
                                         selected_length, sku_area_limit);
}

void evdi_connect2(evdi_handle handle, const unsigned char *edid,
                   const unsigned int edid_length,
                   const uint32_t pixel_area_limit,
                   const uint32_t pixel_per_second_limit) {
  typedef void (*real_fn)(evdi_handle, const unsigned char *,
                          const unsigned int, const uint32_t, const uint32_t);
  unsigned int selected_length;
  const unsigned char *selected_edid =
      edid_for_connect(edid, edid_length, &selected_length);
  ((real_fn)real_symbol("evdi_connect2"))(
      handle, selected_edid, selected_length, pixel_area_limit,
      pixel_per_second_limit);
}

void evdi_disconnect(evdi_handle handle) {
  typedef void (*real_fn)(evdi_handle);
  ((real_fn)real_symbol("evdi_disconnect"))(handle);
}

void evdi_enable_cursor_events(evdi_handle handle, bool enable) {
  typedef void (*real_fn)(evdi_handle, bool);
  ((real_fn)real_symbol("evdi_enable_cursor_events"))(handle, enable);
}

void evdi_grab_pixels(evdi_handle handle, struct evdi_rect *rects,
                      int *num_rects) {
  typedef void (*real_fn)(evdi_handle, struct evdi_rect *, int *);
  ((real_fn)real_symbol("evdi_grab_pixels"))(handle, rects, num_rects);
}

void evdi_register_buffer(evdi_handle handle, struct evdi_buffer buffer) {
  typedef void (*real_fn)(evdi_handle, struct evdi_buffer);
  ((real_fn)real_symbol("evdi_register_buffer"))(handle, buffer);
}

void evdi_unregister_buffer(evdi_handle handle, int buffer_id) {
  typedef void (*real_fn)(evdi_handle, int);
  ((real_fn)real_symbol("evdi_unregister_buffer"))(handle, buffer_id);
}

bool evdi_request_update(evdi_handle handle, int buffer_id) {
  typedef bool (*real_fn)(evdi_handle, int);
  return ((real_fn)real_symbol("evdi_request_update"))(handle, buffer_id);
}

void evdi_ddcci_response(evdi_handle handle, const unsigned char *buffer,
                         const uint32_t buffer_length, const bool result) {
  typedef void (*real_fn)(evdi_handle, const unsigned char *, const uint32_t,
                          const bool);
  ((real_fn)real_symbol("evdi_ddcci_response"))(handle, buffer, buffer_length,
                                                result);
}

void evdi_handle_events(evdi_handle handle, struct evdi_event_context *evtctx) {
  typedef void (*real_fn)(evdi_handle, struct evdi_event_context *);
  ((real_fn)real_symbol("evdi_handle_events"))(handle, evtctx);
}

evdi_selectable evdi_get_event_ready(evdi_handle handle) {
  typedef evdi_selectable (*real_fn)(evdi_handle);
  return ((real_fn)real_symbol("evdi_get_event_ready"))(handle);
}

void evdi_get_lib_version(struct evdi_lib_version *version) {
  typedef void (*real_fn)(struct evdi_lib_version *);
  ((real_fn)real_symbol("evdi_get_lib_version"))(version);
}

void evdi_set_logging(struct evdi_logging evdi_logging) {
  typedef void (*real_fn)(struct evdi_logging);
  ((real_fn)real_symbol("evdi_set_logging"))(evdi_logging);
}

bool Xorg_running(void) {
  typedef bool (*real_fn)(void);
  return ((real_fn)real_symbol("Xorg_running"))();
}
