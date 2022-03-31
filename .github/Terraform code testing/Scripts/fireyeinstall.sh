#!/bin/bash
sleep 1m

tar xzvf "IMAGE_HX_AGENT_LINUX_33.46.6 (1).tgz"
rpm –ihv "IMAGE_HX_AGENT_LINUX_33.46.6 (1)/xagt-33.46.6-1.el7.x86_64.rpm"
/opt/fireeye/bin/xagt -i agent_config.json
systemctl start xagt