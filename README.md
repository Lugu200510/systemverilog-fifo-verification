# SystemVerilog FIFO RTL 设计与验证

## 项目简介

本项目实现了一个参数化同步 FIFO（First In First Out，先进先出队列），并使用 SystemVerilog 搭建了完整的自检验证环境。

FIFO 支持可配置的数据位宽和存储深度，并实现了满/空状态判断、almost-full / almost-empty 状态指示、环形读写指针、同时读写、溢出保护和下溢保护等功能。

验证环境包含定向测试、随机回归测试、基于 SystemVerilog Queue 的参考模型、SystemVerilog Assertions（SVA）、功能覆盖率以及交叉覆盖率。

## FIFO 功能

- 支持参数化数据位宽
- 支持参数化 FIFO 深度
- 同步读写操作
- Full 状态检测
- Empty 状态检测
- Almost Full 状态检测
- Almost Empty 状态检测
- 环形写指针与读指针管理
- 支持同时读写
- 写满保护（Overflow Protection）
- 读空保护（Underflow Protection）
- 支持非 2 的整数次幂深度

## 验证功能

- SystemVerilog 自检 Testbench
- 基于 Queue 的参考模型
- 定向功能测试
- 随机回归测试
- 边界条件测试
- 同时读写测试
- 指针回绕测试
- Overflow / Underflow 测试
- 运行过程中复位测试
- SystemVerilog Assertions
- Functional Coverage
- Cross Coverage
- VCS / Verdi 自动化仿真流程

## 验证内容

Testbench 主要覆盖以下测试场景：

1. 复位功能验证
2. 空 FIFO 读取保护
3. 单次写入与读取
4. FIFO 写满状态
5. 满状态继续写入保护
6. FIFO 数据顺序验证
7. 同时读写功能
8. 空状态下同时读写
9. 满状态下同时读写
10. 读写指针回绕
11. Almost Full / Almost Empty 阈值验证
12. 完整输入数据空间测试
13. 随机回归测试
14. 工作过程中复位
15. 覆盖率收敛测试

## 覆盖率结果

### 代码覆盖率

| 指标 | 覆盖率 |
| --- | ---: |
| Line Coverage | 100% |
| Toggle Coverage | 100% |
| Condition Coverage | 100% |
| Branch Coverage | 100% |

由于 FIFO RTL 中没有使用显式有限状态机，因此 FSM Coverage 不适用于本项目。

### 功能覆盖率

| 指标 | 结果 |
| --- | ---: |
| Cover Points | 20 / 20 |
| Cover Point Bins | 83 / 83 |
| Crosses | 3 / 3 |
| Cross Bins | 12 / 12 |
| Functional Coverage | 100% |

## 使用工具

- SystemVerilog
- Synopsys VCS
- Synopsys Verdi
- Synopsys URG
- Bash
- C Shell（可选，用于 EDA 环境加载）

## 仿真运行方法

本项目默认使用以下源码路径：

```text
rtl/fifo.sv
tb/fifo_tb.sv
sim/run.sh
```

进入仿真目录：

```bash
cd sim
```

为脚本添加执行权限：

```bash
chmod +x run.sh
```

运行完整仿真流程：

```bash
./run.sh
```

`run.sh` 会自动完成以下操作：

- 检查 VCS / URG / Verdi 工具环境
- 清理旧的仿真文件
- 自动生成 filelist.f
- 使用 VCS 编译 RTL 与 Testbench
- 运行仿真
- 生成代码覆盖率数据库
- 生成 URG 覆盖率报告
- 自动打开 Verdi 波形界面
- 自动打开 Verdi Coverage 界面

## EDA 环境加载

如果服务器使用 Environment Modules 管理 EDA 工具，可以先运行：

```csh
source sim/load_eda.csh
```

`load_eda.csh` 用于加载指定版本的 Synopsys VCS 和 Verdi，并检查相关工具路径及 DISPLAY 环境变量。

该脚本与具体服务器环境相关，不同平台上的 module 名称和软件版本可能需要进行相应修改。

## 自动生成文件

VCS、Verdi 和 URG 在编译、仿真及覆盖率分析过程中会产生大量临时文件，例如：

```text
simv
simv.daidir/
simv.vdb/
csrc/
urgReport/
*.vpd
*.fsdb
*.log
AN.DB/
```

这些文件均通过 `.gitignore` 排除，不会提交到 GitHub 仓库。

## 说明

本项目包含 FIFO RTL 设计、SystemVerilog 验证环境以及自动化仿真脚本，可在配置有 Synopsys VCS / Verdi 的 EDA 环境中完成完整的编译、仿真、波形分析和覆盖率验证流程。
