**English** | [中文](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

# Actions-OpenWrt

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Forks&logo=github)

A template for building OpenWrt with GitHub Actions

## Usage

- Click the [Use this template](https://github.com/new?template_name=Action-Immortalwrt-x86&template_owner=YuasKD) button to create a new repository.
- Generate `.config` files using [Immortalwrt](https://github.com/immortalwrt/immortalwrt) source code. ( You can change it through environment variables in the workflow file. )
- Push `.config` file to the GitHub repository.
- Select `Build OpenWrt` on the Actions page.
- Click the `Run workflow` button.
- When the build is complete, click the `Artifacts` button in the upper right corner of the Actions page to download the binaries.
- If you wish to generate firmware with the default configuration, please remove all contents from diy-part2.sh except for the line "#!/bin/bash."
- If you wish to upload the firmware to the Release section, the best practice is to update the token: ${{ secrets."action name" }} field in openwrt-builder.yml with a self-created token that has repo permissions.

## Tips

- It may take a long time to create a `.config` file and build the OpenWrt firmware. Thus, before create repository to build your own firmware, you may check out if others have already built it which meet your needs by simply [search `Actions-Openwrt` in GitHub](https://github.com/search?q=Actions-openwrt).
- Add some meta info of your built firmware (such as firmware architecture and installed packages) to your repository introduction, this will save others' time.
- If you see an error log in the terminal similar to the following (Under the Hyper-V):

  hv_netvsc cd9dd876-2fa9-4764-baa7-b44482f85f9f eth0: nvsp_rndis_pkt_complete error status: 2

  Please follow the steps below to disable TX checksumming:

  vim /etc/rc.local

    !/bin/sh

    (sleep 5 && ethtool -K eth0 tx off) &

    exit 0

  - Here are some of the commonly used plugins:
    
    ![image](https://github.com/user-attachments/assets/b9b7db6e-e5a0-4fde-871c-8970e14853bd)
    
    ![image](https://github.com/user-attachments/assets/a8a0e4bd-dbb8-402d-a507-f762c8ce77cc)
    
    ![image](https://github.com/user-attachments/assets/0c934c9c-fd5c-41b7-a1ac-3b76f6d8f8e7)
    
    ![image](https://github.com/user-attachments/assets/b3309a63-6e49-451b-986c-4f9d523470da)
    
    ![image](https://github.com/user-attachments/assets/bed1a485-67e9-4908-9282-a68bfb1fec94)







  
## Credits

- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [DHDAXCW/OpenWRT_x86_x64](https://github.com/DHDAXCW/OpenWRT_x86_x64)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Mattraks/delete-workflow-runs](https://github.com/Mattraks/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## License

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [**P3TERX**](https://p3terx.com)
