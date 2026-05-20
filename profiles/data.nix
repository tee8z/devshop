{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python3Packages.pandas
    python3Packages.pyarrow
    sqlite
    sqlitebrowser
    duckdb
  ];
}
