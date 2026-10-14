# 仓库镜像部署

`pro` 分支推送后，GitHub Actions 构建并测试全新安装、容器重建、配置和上传文件及数据库保留。测试通过才发布：

- `ghcr.io/anlongvip/dootask:latest`
- `ghcr.io/anlongvip/dootask:sha-完整提交号`（用于固定版本）

只需要更新 `php` 服务的应用镜像。Nginx、MariaDB、Redis、应用商店使用各自的官方镜像。应用启动时把镜像中的程序同步到专用数据卷，保留配置、上传文件、存储、许可证和插件目录，然后执行数据库迁移；首次安装额外初始化数据。迁移失败时不会启动后端。

## 宝塔首次部署

在 Docker → 容器编排创建项目，粘贴同目录 `compose.yml`，设置环境变量：

```dotenv
DB_PASSWORD=替换为至少16位随机字符
DB_ROOT_PASSWORD=替换为另外一组至少16位随机字符
APP_PORT=2222
APP_URL=http://localhost:2222
BIND_IP=127.0.0.1
```

默认仅监听服务器本机。私人使用可以通过 SSH 隧道或 Tailscale 转发访问，不需要开放公网看板端口。实际访问地址确定后再调整 APP_URL；它只在首次安装写入应用配置，后续修改要编辑数据卷内的 `.env`。

首次管理员账号和随机密码位于 `dootask_source` 数据卷的 `storage/app/install-credentials.txt`，文件权限为 600，不会写入容器日志。首次登录后修改密码。保管数据库密码；不要将部署环境文件提交到仓库。

源代码和数据卷位置为 `/var/lib/docker/volumes/dootask_source/_data`，适用于宝塔默认的 Docker 数据目录。如果 Docker 数据目录不同，需同步调整 appstore 的 HOST_PWD。应用商店需要 Docker socket，具备管理服务器容器的能力。

## 后续更新

1. 更新前备份 `dootask_database` 和 `dootask_source` 数据卷，数据库备份应使用数据库导出或停机快照。
2. 在宝塔容器编排里拉取新的应用镜像。
3. 停止看板编排，再重新创建并启动服务，等待健康检查通过；不要删除数据卷。

无需在服务器安装前端依赖或重新编译。配置密钥、账号、任务和上传文件由数据卷保留。数据库迁移可能不可逆，回退时应配合更新前的数据库备份，不要只退镜像。

镜像部署关闭应用内的「系统更新」（`ONLINE_UPDATE=false`），统一在宝塔更新镜像。前端依赖锁定在 `docker/image/package-lock.json`；修改前端依赖时应同时更新该锁文件。

这是 2GB 机器的低内存起步配置，不保证无限数量的网站或插件；部署后再根据实际内存占用调整。
