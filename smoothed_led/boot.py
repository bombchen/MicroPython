import network
import time

def connect_wifi(ssid, password):
    """连接WiFi（可选）"""
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    if not wlan.isconnected():
        print('连接到WiFi网络...')
        wlan.connect(ssid, password)
        
        # 等待连接
        for i in range(10):
            if wlan.isconnected():
                break
            time.sleep(1)
    
    if wlan.isconnected():
        print('网络配置:', wlan.ifconfig())
    else:
        print('WiFi连接失败')

# 如果需要WiFi连接，取消注释并填写你的网络信息
# connect_wifi('你的WiFi名称', '你的WiFi密码')

print("系统启动完成")