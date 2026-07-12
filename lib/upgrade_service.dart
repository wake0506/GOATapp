import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpgradeService {
  // 替换成你自己的 GitHub Raw 链接
  static const String versionUrl =
      "https://raw.githubusercontent.com/wake0506/GOATapp/main/version.json";

  static Future<void> checkUpdate(BuildContext context) async {
    try {
      // 1. 获取当前版本
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int localVersion = int.parse(packageInfo.buildNumber);

      // 2. 获取服务器版本
      var response = await Dio().get(versionUrl);
      var data = response.data;
      // 注意：如果 GitHub 返回的是 String，需要 jsonDecode(data)
      int serverVersion = data['versionCode'];

      if (serverVersion > localVersion) {
        // 3. 弹出对话框提示更新 (这里用简单的示例)
        _showUpdateDialog(context, data['apkUrl'], data['updateLog']);
      }
    } catch (e) {
      debugPrint("检查更新失败: $e");
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String apkUrl,
    String log,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("发现新版本"),
        content: Text(log),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("以后再说"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAndInstall(apkUrl);
            },
            child: Text("立即更新"),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(String url) async {
    // 1. 获取下载路径
    Directory? tempDir = await getExternalStorageDirectory();
    String path = "${tempDir!.path}/temp_update.apk";

    // 2. 执行下载
    debugPrint("开始下载...");
    await Dio().download(
      url,
      path,
      onReceiveProgress: (count, total) {
        debugPrint("下载进度: ${(count / total * 100).toStringAsFixed(0)}%");
      },
    );

    // 自动安装插件尚未接入；当前先保留下载能力，避免阻塞项目构建。
    debugPrint('安装包已下载到: $path');
  }
}
