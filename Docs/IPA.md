# 真机 IPA 构建

`.github/workflows/ios-ipa.yml` 会在 GitHub 的 macOS runner 上归档并导出签名 IPA。它只支持手动触发，避免公开仓库的普通 PR 在没有签名材料时失败。

## 必需的 GitHub Actions secrets

在仓库的 **Settings → Secrets and variables → Actions** 中添加以下 secrets：

| Secret | 内容 |
| --- | --- |
| `IOS_TEAM_ID` | Apple Developer Team ID |
| `IOS_SIGNING_CERTIFICATE_BASE64` | 导出的 `.p12` 证书文件进行 base64 编码后的内容 |
| `IOS_SIGNING_CERTIFICATE_PASSWORD` | `.p12` 导出密码 |
| `IOS_PROVISIONING_PROFILE_BASE64` | 与 `com.whisper.ios` 匹配的 `.mobileprovision` 文件进行 base64 编码后的内容 |
| `IOS_CODE_SIGN_IDENTITY` | 可选；默认 Development 使用 `Apple Development`，Ad Hoc 使用 `Apple Distribution` |

不要把证书、`.p12`、`.mobileprovision` 或密码提交到仓库，也不要发送到聊天中。GitHub Actions secrets 只通过工作流环境注入。

## 选择哪种导出方式

- `development`：适合开发验证；设备 UDID 必须包含在 Development provisioning profile 中。
- `ad-hoc`：适合向已注册设备分发；设备 UDID 必须包含在 Ad Hoc provisioning profile 中。

两种方式都需要 Apple Developer Program 的签名证书和 provisioning profile。仅有源代码或 GitHub runner 不能生成可安装到真机的签名 IPA。

## 运行

1. 配置上面的 4 个必需 secrets。
2. 打开 GitHub Actions → **iOS IPA** → **Run workflow**。
3. 选择 `development` 或 `ad-hoc`。
4. 等待完成后，在 workflow run 的 Artifacts 下载 `whisper-*-ipa-*`。

当前 bundle ID 是 `com.whisper.ios`，定义在 `project.yml` 中。
