/* MediaRemoteAdapter 导出面（S7 D37）：供宿主（perl/DynaLoader 等）装载。 */
#ifndef MEDIAREMOTE_ADAPTER_H
#define MEDIAREMOTE_ADAPTER_H
#ifdef __cplusplus
extern "C" {
#endif
void bootstrap(void);
int probe(void);
int get_sync(char *buf, int len);
void loop(void);
#ifdef __cplusplus
}
#endif
#endif
