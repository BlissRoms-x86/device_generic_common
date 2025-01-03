#pragma once

namespace android {
namespace bootable {
class BootControlExt {
  public:
    bool SetBootSlot(const char* new_suffix);
};
}
}
