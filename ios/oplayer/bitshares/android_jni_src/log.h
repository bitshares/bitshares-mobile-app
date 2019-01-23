#ifndef __fowallet_log_h__
#define __fowallet_log_h__

#ifdef __cplusplus
extern "C"
{
#endif  //  __cplusplus

#include <android/log.h>
#define LOG_TAG "fowallet"
#if DEBUG
	#define  LOGV(...)  __android_log_print(ANDROID_LOG_VERBOSE,LOG_TAG,__VA_ARGS__)
	#define  LOGE(...)  __android_log_print(ANDROID_LOG_ERROR,LOG_TAG,__VA_ARGS__)
	#define  LOGW(...)  __android_log_print(ANDROID_LOG_WARN,LOG_TAG,__VA_ARGS__)
	#define  LOGD(...)  __android_log_print(ANDROID_LOG_DEBUG,LOG_TAG,__VA_ARGS__)
	#define  LOGI(...)  __android_log_print(ANDROID_LOG_INFO,LOG_TAG,__VA_ARGS__)
#else
	#define  LOGV(...)
	#define  LOGE(...)
	#define  LOGW(...)
	#define  LOGD(...)
	#define  LOGI(...)
#endif
//	crashlytics log
// extern void cls_log(const char* message);

#ifdef __cplusplus
}
#endif  //  __cplusplus

#endif /* __fowallet_log_h__ */