# device_calendar 插件 ProGuard 规则
# 防止 R8 代码压缩时删除 device_calendar 的关键类
-keep class com.builttoroam.devicecalendar.** { *; }
