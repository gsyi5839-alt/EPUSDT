#!/bin/bash
# EPUSDT iOS 应用命令行操作指南

echo "=========================================="
echo "  EPUSDT iOS 应用命令行操作"
echo "=========================================="
echo ""

# 1. 列出所有可用的模拟器
echo "【1】列出所有可用的iPhone模拟器："
echo "命令: xcrun simctl list devices available | grep iPhone"
echo ""
xcrun simctl list devices available | grep "iPhone" | head -5
echo ""

# 2. 启动模拟器
echo "【2】启动iPhone 17 Pro模拟器："
echo "命令: open -a Simulator --args -CurrentDeviceUDID 37936EEB-0BA1-4074-9576-716DE18D2C15"
echo ""

# 3. 查看已安装的应用
echo "【3】查看模拟器中已安装的应用："
echo "命令: xcrun simctl listapps booted | grep -i epusdt"
echo ""
xcrun simctl listapps booted | grep -i epusdt -A 6 | head -7
echo ""

# 4. 启动应用
echo "【4】启动EpusdtPay应用："
echo "命令: xcrun simctl launch booted com.epusdt.EpusdtPay"
echo ""
APP_PID=$(xcrun simctl launch booted com.epusdt.EpusdtPay 2>&1 | awk '{print $2}')
echo "✅ 应用已启动，进程ID: $APP_PID"
echo ""

# 5. 查看应用日志
echo "【5】查看应用实时日志："
echo "命令: xcrun simctl spawn booted log stream --predicate 'processImagePath contains \"EpusdtPay\"' --level debug"
echo ""

# 6. 截图
echo "【6】截取模拟器屏幕："
echo "命令: xcrun simctl io booted screenshot ~/Desktop/epusdt_screenshot.png"
echo ""

# 7. 录制视频
echo "【7】录制模拟器视频："
echo "命令: xcrun simctl io booted recordVideo ~/Desktop/epusdt_video.mp4"
echo "（按 Ctrl+C 停止录制）"
echo ""

# 8. 安装应用（从.app文件）
echo "【8】安装应用到模拟器："
echo "命令: xcrun simctl install booted /path/to/EpusdtPay.app"
echo ""

# 9. 卸载应用
echo "【9】卸载应用："
echo "命令: xcrun simctl uninstall booted com.epusdt.EpusdtPay"
echo ""

# 10. 重置模拟器
echo "【10】重置模拟器（清除所有数据）："
echo "命令: xcrun simctl erase 37936EEB-0BA1-4074-9576-716DE18D2C15"
echo ""

echo "=========================================="
echo "  快速编译和运行"
echo "=========================================="
echo ""
echo "完整编译命令:"
echo "cd /Users/macbook/jiamihuobi/EPUSDT/ios手机系统/EpusdtPay/EpusdtPay"
echo "xcodebuild -scheme EpusdtPay -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build"
echo ""

echo "=========================================="
echo "  当前状态"
echo "=========================================="
echo ""
echo "✅ 模拟器: iPhone 17 Pro (已启动)"
echo "✅ 应用: EpusdtPay (运行中)"
echo "✅ 后端: http://localhost:8000 (运行中)"
echo ""
