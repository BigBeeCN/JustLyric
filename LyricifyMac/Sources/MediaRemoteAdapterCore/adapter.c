// MediaRemoteAdapter（S7 D37）：MediaRemote 读取核心。
// [红线-P2] **全仓 MediaRemote 符号单点**（QA 符号扫描项随迁至本文件）。
// 宿主形态：Apple 平台二进制（perl/DynaLoader 等）加载本 dylib（信任位 512 前提，Spike-3 根因）。
// 导出：bootstrap / probe / get_sync / loop（JSON lines 流式，D37 #4）。
#include <dlfcn.h>
#include <dispatch/dispatch.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>
int probe(void); /* 前向声明 */

typedef void (*fn_getinfo)(void *, void (^)(void *));
typedef void (*fn_getpid)(void *, void (^)(int));
typedef void (*fn_getplaying)(void *, void (^)(unsigned char));
typedef void (*fn_register)(void *);

static void *lib;
static fn_getinfo p_getinfo;
static fn_getpid p_getpid;
static fn_getplaying p_getplaying;
static fn_register p_register;

void bootstrap(void) {
    lib = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    if (!lib) { printf("{\"type\":\"bootstrap\",\"ok\":false,\"dlopen\":false}\n"); fflush(stdout); return; }
    p_getinfo = (fn_getinfo)dlsym(lib, "MRMediaRemoteGetNowPlayingInfo");
    p_getpid = (fn_getpid)dlsym(lib, "MRMediaRemoteGetNowPlayingApplicationPID");
    p_getplaying = (fn_getplaying)dlsym(lib, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    p_register = (fn_register)dlsym(lib, "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (p_register) { p_register(dispatch_get_global_queue(0, 0)); }
    printf("{\"type\":\"bootstrap\",\"ok\":%s,\"getinfo\":%d,\"getpid\":%d,\"getplaying\":%d,\"register\":%d}\n",
        probe() ? "true" : "false", p_getinfo != 0, p_getpid != 0, p_getplaying != 0, p_register != 0);
    fflush(stdout);
}

void get(void) {
    if (!p_getinfo) { printf("{\"error\":\"no symbol\"}\n"); return; }
    p_getpid(dispatch_get_global_queue(0, 0), ^(int pid) {
        printf("{\"type\":\"pid\",\"value\":%d}\n", pid); fflush(stdout);
    });
    p_getplaying(dispatch_get_global_queue(0, 0), ^(unsigned char playing) {
        printf("{\"type\":\"playing\",\"value\":%s}\n", playing ? "true" : "false"); fflush(stdout);
    });
    p_getinfo(dispatch_get_global_queue(0, 0), ^(void *info) {
        if (!info) { printf("{\"type\":\"info\",\"value\":null}\n"); fflush(stdout); return; }
        // 枚举键值
        CFDictionaryRef dict = (CFDictionaryRef)info;
        CFIndex count = CFDictionaryGetCount(dict);
        printf("{\"type\":\"info\",\"keys\":%ld}\n", (long)count); fflush(stdout);
    });
}

static void print_key(CFDictionaryRef dict, void *lib, const char *sym, const char *label) {
    void *p = dlsym(lib, sym);
    if (!p) return;
    CFStringRef key = *(CFStringRef *)p;
    CFTypeRef val = CFDictionaryGetValue(dict, key);
    if (!val) return;
    if (CFGetTypeID(val) == CFStringGetTypeID()) {
        char buf[256];
        CFStringGetCString((CFStringRef)val, buf, sizeof(buf), kCFStringEncodingUTF8);
        printf("{\"type\":\"field\",\"key\":\"%s\",\"value\":\"%s\"}\n", label, buf);
    } else if (CFGetTypeID(val) == CFNumberGetTypeID()) {
        double d; CFNumberGetValue((CFNumberRef)val, kCFNumberDoubleType, &d);
        printf("{\"type\":\"field\",\"key\":\"%s\",\"value\":%f}\n", label, d);
    }
    fflush(stdout);
}

void dump_info(void) {
    if (!p_getinfo) return;
    p_getinfo(dispatch_get_global_queue(0, 0), ^(void *info) {
        if (!info) { printf("{\"type\":\"dump\",\"value\":null}\n"); fflush(stdout); return; }
        CFDictionaryRef dict = (CFDictionaryRef)info;
        print_key(dict, lib, "kMRMediaRemoteNowPlayingInfoTitle", "title");
        print_key(dict, lib, "kMRMediaRemoteNowPlayingInfoArtist", "artist");
        print_key(dict, lib, "kMRMediaRemoteNowPlayingInfoAlbum", "album");
        print_key(dict, lib, "kMRMediaRemoteNowPlayingInfoDuration", "duration");
        print_key(dict, lib, "kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsed");
    });
}


// —— D37 导出面 ——
#include <dispatch/dispatch.h>
static void append_key(char *out, CFDictionaryRef dict, const char *sym, const char *label);
static void append_num(char *out, CFDictionaryRef dict, const char *sym, const char *label);

// 探针：1=符号齐全可服务（D37 #2 启动能力探测）。
int probe(void) {
    return (p_getinfo && p_getpid && p_getplaying && p_register) ? 1 : 0;
}

// 同步取数：写入 buf（JSON），返回写入长度（<100ms，D37 #4）。
int get_sync(char *buf, int len) {
    if (!p_getinfo || !buf || len <= 0) return -1;
    __block int written = -1;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    // D43 条件③回溯/复测：载荷附 pid（Spike-3 已证可取）。
    __block int nowPlayingPID = -1;
    dispatch_semaphore_t pid_sem = dispatch_semaphore_create(0);
    if (p_getpid) {
        p_getpid(dispatch_get_global_queue(0, 0), ^(int pid) {
            nowPlayingPID = pid;
            dispatch_semaphore_signal(pid_sem);
        });
        dispatch_semaphore_wait(pid_sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)));
    }
    p_getinfo(dispatch_get_global_queue(0, 0), ^(void *info) {
        char tmp[2048] = "{\"type\":\"state\"";
        if (info) {
            CFDictionaryRef dict = (CFDictionaryRef)info;
            append_key(tmp, dict, "kMRMediaRemoteNowPlayingInfoTitle", "title");
            append_key(tmp, dict, "kMRMediaRemoteNowPlayingInfoArtist", "artist");
            append_key(tmp, dict, "kMRMediaRemoteNowPlayingInfoAlbum", "album");
            append_num(tmp, dict, "kMRMediaRemoteNowPlayingInfoDuration", "durationMs");
            append_num(tmp, dict, "kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsedMs");
        }
        char pid_kv[64];
        snprintf(pid_kv, sizeof(pid_kv), ",\"pid\":%d", nowPlayingPID);
        strcat(tmp, pid_kv);
        strcat(tmp, "}");
        written = (int)strlen(tmp);
        if (written >= len) written = len - 1;
        memcpy(buf, tmp, written);
        buf[written] = 0;
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.09 * NSEC_PER_SEC)));
    return written;
}

static void append_key(char *out, CFDictionaryRef dict, const char *sym, const char *label) {
    void *p = dlsym(lib, sym);
    if (!p) return;
    CFStringRef key = *(CFStringRef *)p;
    CFTypeRef val = CFDictionaryGetValue(dict, key);
    if (!val || CFGetTypeID(val) != CFStringGetTypeID()) return;
    char v[256];
    if (!CFStringGetCString((CFStringRef)val, v, sizeof(v), kCFStringEncodingUTF8)) return;
    char kv[320];
    snprintf(kv, sizeof(kv), ",\"%s\":\"%s\"", label, v);
    strcat(out, kv);
}

static void append_num(char *out, CFDictionaryRef dict, const char *sym, const char *label) {
    void *p = dlsym(lib, sym);
    if (!p) return;
    CFStringRef key = *(CFStringRef *)p;
    CFTypeRef val = CFDictionaryGetValue(dict, key);
    if (!val || CFGetTypeID(val) != CFNumberGetTypeID()) return;
    double d = 0;
    CFNumberGetValue((CFNumberRef)val, kCFNumberDoubleType, &d);
    char kv[96];
    snprintf(kv, sizeof(kv), ",\"%s\":%.0f", label, d * 1000.0);
    strcat(out, kv);
}

// 流式循环：变化时输出 JSON line（宿主常驻用，D37 #4）。
void loop(void) {
    char last[2048] = "";
    for (;;) {
        char now[2048] = "";
        if (get_sync(now, sizeof(now)) > 0 && strcmp(now, last) != 0) {
            printf("%s\n", now);
            fflush(stdout);
            strcpy(last, now);
        }
        usleep(150 * 1000); // D42 预算修正：事件检出 <300ms（原 400ms 超预算）
    }
}


// 打印式取数（D37 #4 单查；xsub 不传指针，规避 SV* 桥接）。
void get_json(void) {
    char buf[2048];
    int n = get_sync(buf, (int)sizeof(buf));
    if (n > 0) { printf("%s\n", buf); }
    else { printf("{\"type\":\"state\",\"error\":\"empty\"}\n"); }
    fflush(stdout);
}
