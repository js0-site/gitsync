# gitsync 项目说明

本项目通过一个定时执行的 GitHub Action，实现从 AtomGit 到 GitHub 的仓库自动同步。

## 工作原理

同步过程由 `.github/workflows/gitsync.yml` 中定义的 GitHub Actions 工作流驱动。以下是详细步骤：

1.  **定时触发**: 工作流被设置为每 5 分钟运行一次。
2.  **代码检出**: 工作流会检出当前仓库，以及一个独立的私有仓库 `conf`。这个私有仓库用于存放敏感凭证。
3.  **环境设置**: 设置 `bun` 运行时环境，并根据 `package.json` 安装依赖。
4.  **身份验证**: 工作流通过链接 `conf` 仓库中的 SSH 密钥 (`conf/ssh`) 并加载 `conf/gitsync` 目录下的 `.env` 文件来配置身份验证信息。
5.  **执行脚本**: 运行 `run.sh` 脚本，该脚本会启动主同步程序 `main.js`。
6.  **执行同步**: `main.js` 脚本调用 `@3-/gitsync` 库，将 AtomGit 上 `js0` 组织下的所有仓库同步到 GitHub 上的 `js0-site` 组织。`sync.yml` 文件用于维护同步状态，由脚本自动管理。如果目标仓库不存在，会自动创建。 **[@3-/gitsync](https://www.npmjs.com/package/@3-/gitsync) 库还会通过大语言模型为代码生成 Git 的提交备注**。
7.  **自我更新**: 如果在此过程中，本仓库的任何文件（例如 `sync.yml`）被修改，工作流会自动将这些变更提交并推送到 `main` 分支。

## 如何配置

要将此项目用于你自己的目的，需要进行以下配置：

### `sync.yml`

该文件由 `@3-/gitsync` 库自动生成和管理，用于跟踪仓库的同步状态。它存储了每个仓库最后一次同步的提交信息，以避免重复同步未更改的仓库并确保状态一致。

通常情况下，你不应该手动编辑此文件，除非你需要解决冲突或重置特定仓库的同步状态。该文件的内容大致如下，将仓库名称映射到其同步数据：

示例:
```yaml
repo-one:
  - <some_sync_data>
repo-two:
  - <some_sync_data>
```

### 私有 `conf` 仓库

你需要一个私有的 GitHub 仓库来存储敏感信息。该仓库应命名为 `conf`，并且与 `gitsync` 仓库属于同一个所有者（用户或组织）。

`conf` 仓库需要包含以下结构：

```
conf/
├── gitsync/
│   ├── atomgit.env
│   ├── github.env
│   └── ...           # 其他 .env 文件
└── ssh/
    ├── config        # SSH 客户端配置
    └── id_ed25519    # 用于 Git 访问的私钥
```

-   **`gitsync/`**: 此目录包含 `.env` 文件，每个文件定义特定的环境变量。`run.sh` 脚本会加载此目录下的所有 `.env` 文件。例如：
    -   `atomgit.env`: 定义 `ATOMGIT_TOKEN`。
    -   `github.env`: 定义 `GITHUB_TOKEN`。
    -   `modelscope.env`: 定义 `OPENAI_API_KEY`。
    -   `modelscopeModel.env`: 定义 `OPENAI_BASE_URL` 和 `OPENAI_MODEL`。
    -   `tavily.env`: 定义 `TAVILY_API_KEY`。
-   **`ssh/`**: 此目录包含 SSH 配置。
    -   `id_ed25519`: 用于向 Git 提供商进行身份验证的私钥。工作流会确保它具有正确的权限 (`600`)。
    -   `config`: SSH 配置文件，用于指定为哪个主机使用哪个密钥。

### GitHub Actions 工作流

本项目的自动化由 `.github/workflows` 目录下的两个工作流文件管理。

-   **`gitsync.yml`**: 这是负责同步的核心工作流。
    -   **触发方式**: 每 5 分钟定时执行 (`cron`)，也支持手动触发 (`workflow_dispatch`)。
    -   **执行过程**: 检出项目代码和私有的 `conf` 仓库，设置 Bun 环境，安装依赖，并运行 `./run.sh` 脚本来启动同步。
    -   **自我更新**: 同步完成后，它会检查仓库本身是否有任何变更（例如 `sync.yml` 的更新），并将这些变更推送回 `main` 分支。

-   **`keep-alive.yml`**: 此工作流用于确保仓库保持活跃，以防止 GitHub 因仓库不活跃而禁用定时任务。
    -   **触发方式**: 每月运行一次。
    -   **执行过程**: 它会用当前月份更新 `.date` 文件，然后提交并推送该变更。

除了工作流文件，你还需要配置以下内容：

-   **Secrets**: 必须创建一个具有 `repo` 范围的个人访问令牌 (PAT)，并将其存储为名为 `GH_PAT` 的仓库秘密。此令牌用于检出私有的 `conf` 仓库。
-   **同步源与目标**: 同步的源和目标在 `main.js` 中是硬编码的。你可能需要修改 `sync()` 函数的调用参数：
    ```javascript
    await sync(join(ROOT, "sync.yml"), ATOMGIT, "js0", GITHUB, "js0-site");
    ```

## 依赖项

-   [Bun](https://bun.sh/): JavaScript 运行时。
-   [@3-/gitsync](https://www.npmjs.com/package/@3-/gitsync): 核心同步库。
