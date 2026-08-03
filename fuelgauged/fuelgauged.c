/*
 * fuelgauged - 64-bit launcher for the MTK GM30 fuel gauge daemon library.
 *
 * Mirrors the stock 32-bit /vendor/bin/fuelgauged shim, which only dlopens
 * libfgauge_gm30.so and calls its exported libfgauge_setup() entry point.
 * Built as a 64-bit binary so it runs on the recovery ramdisk (which ships
 * no 32-bit runtime) without pulling in the whole 32-bit library set.
 *
 * Runtime deps (present in the recovery ramdisk):
 *   /vendor/lib64/libfgauge_gm30.so
 *   /vendor/lib64/libmtk_drvb.so        (+ /vendor/lib64/mt6833/libmtk_drvb.so)
 *   /system/lib64/{libc,libm,libdl,liblog,libcutils,libutils,libc++}.so
 *
 * libfgauge_setup() returns 11 when it cannot open the netlink socket to the
 * gauge driver (the module may not be loaded yet right after boot); on success
 * it returns 12. The stock shim relies on init restarting the service; we
 * additionally retry the socket-error case in-process to survive module-load
 * timing without service churn.
 *
 * Rebuild (Android NDK):
 *   aarch64-linux-android31-clang -O2 -fPIE -pie fuelgauged.c -o fuelgauged -ldl
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

#define GM30_LIB "/vendor/lib64/libfgauge_gm30.so"
#define SETUP_SYM "libfgauge_setup"
#define FG_SOCKET_ERROR 0xB

static void klog(const char *msg) {
    int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (fd >= 0) {
        dprintf(fd, "<6>fuelgauged: %s\n", msg);
        close(fd);
    }
}

int main(void) {
    int (*setup)(void);
    int rc;

    klog("launcher start");
    void *handle = dlopen(GM30_LIB, RTLD_NOW);
    if (!handle) {
        klog("dlopen failed");
        return 1;
    }
    setup = (int (*)(void))dlsym(handle, SETUP_SYM);
    if (!setup) {
        klog("dlsym failed");
        return 1;
    }

    /*
     * The service may be started before the `on boot` block has mounted
     * /mnt/vendor/nvcfg and before the gauge module is up. Wait for both:
     * the daemon needs nvcfg (persisted FG state) and the netlink socket
     * (which only exists once mt6359p_battery.ko has probed).
     */
    while (access("/mnt/vendor/nvcfg", R_OK | W_OK) != 0) {
        sleep(2);
    }
    klog("nvcfg ready, calling libfgauge_setup");
    for (;;) {
        rc = setup();
        if (rc == FG_SOCKET_ERROR) {
            klog("socket error, retrying");
            sleep(2);
            continue;
        }
        /*
         * Success (returns 0xC) or any other exit: return so init restarts
         * the service, matching the stock fuelgauged behaviour.
         */
        return rc;
    }
}
