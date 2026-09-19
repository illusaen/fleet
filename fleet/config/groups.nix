{
  wheel = {
    isPosix = true;
    members = ["system-access"];
  };

  networkmanager = {
    isPosix = true;
    members = ["system-access"];
  };

  tty = {
    isPosix = true;
    members = ["system-access"];
  };

  kvm = {
    isPosix = true;
    members = ["system-access"];
  };

  i2c = {
    isPosix = true;
    members = ["system-access"];
  };

  input = {
    isPosix = true;
    members = ["system-access"];
  };

  system-access = {
    isPosix = false;
    members = [];
  };
}
