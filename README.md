# RouterOS CN IP List

CN ip list script generator for MikroTik RouterOS

[![status](https://img.shields.io/github/workflow/status/upbeat-backbone-bose/routeros-cnip-cidr/cnip-cidr-gen?color=34d058&label=cnip-cidr-gen&logo=github&logoColor=fff)](https://github.com/upbeat-backbone-bose/routeros-cnip-cidr/actions/workflows/cnip-cidr-gen.yml)

## To use

```Ros Shell
# CDN, fast
/tool fetch url="https://cdn.jsdelivr.net/gh/upbeat-backbone-bose/routeros-cnip-cidr/dist/cn_ip_cidr.rsc" dst-path=cn.rsc;

# if CDN does't work, use this
/tool fetch url="https://raw.githubusercontent.com/upbeat-backbone-bose/routeros-cnip-cidr/master/dist/cn_ip_cidr.rsc" dst-path=cn.rsc;

/import file-name=cn.rsc;
```

## Tanks to

[RookieZoe](https://github.com/RookieZoe/routeros-cnip-cidr)

[ispip.clang.cn](https://ispip.clang.cn/)

[IceCodeNew](https://github.com/IceCodeNew/4Share)

[gaoyifan](https://github.com/gaoyifan/china-operator-ip)
