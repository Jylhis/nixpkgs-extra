{ lib }:
{
  maintainers = import ./maintainers.nix;
  openviking = import ./openviking { inherit lib; };
}
