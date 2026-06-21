# CLAUDE.md

이 파일은 이 저장소에서 작업하는 Claude Code(및 다른 에이전트)를 위한 가이드입니다.

## 프로젝트 개요

경량 정수형 RISC-V 코어(ORCA, RVX 플랫폼)에는 FPU가 없어
부동소수점 연산이 느리다. 이를 해결하기 위해 **IEEE-754 단정밀도 FPU를 APB 슬레이브 IP로 설계**하고,
K-means clustering 응용의 실수 연산을 이 IP로 가속하는 것이 목표다.

자세한 배경/단계별 task는 [README.md](README.md) 참고. 단계 요약:
- **Step 1**: `fpu_top.v` + `testbench.v` 작성, FPU 모듈 RTL 시뮬레이션 검증
- **Step 2**: `IP_TOP.v`(APB 슬레이브) 완성, `fpu_test.c`로 사칙연산 검증
- **Step 3**: `k_means_oled.c`의 실수 연산을 FPU API로 대체, 결과·가속 비교

## 수정 가능 / 금지 규칙 (중요)

| 파일 | 규칙 |
|------|------|
| `hardware/src/fpu_adder.v`, `fpu_multiplier.v`, `fpu_divider.v` | **수정 금지.** dawsonjon/fpu 라이브러리. git에서 직접 받지 말고 첨부된 파일을 instance |
| `hardware/src/IP_TOP.v` | 주석 처리된 `Please fill in...` 빈칸만 작성. **그 외 부분 수정 금지** |
| `kmeans_fpu.xml` | **수정 금지.** 플랫폼 명세 그대로 사용 (저장소 루트) |
| `software/fpu_test.c` | **수정 금지.** Step 2 검증용 |
| `software/k_means_oled.c` | Step 3에서 실수 연산을 FPU API로 대체 (수정 대상) |
| `hardware/src/fpu_top.v` | **신규 작성** (Step 1) — FPU 사칙연산 제어 top |
| `hardware/testbench/`, `hardware/sim/` | testbench(Vivado) / iverilog 시뮬레이션 결과물 위치 (신규 작성) |

## 핵심 인터페이스

### FPU 모듈 handshake (3개 모듈 공통, 수정 X)
- 입력: `input_a/b` (32b), `input_a/b_stb`(준비), `output_z_ack`
- 출력: `output_z` (32b), `output_z_stb`(준비), `input_a/b_ack`
- stb(데이터 준비) / ack(수신 완료) handshake를 빠짐없이 사용할 것.
- adder/mult/divider 각각 **1개만** 인스턴스 (중복 금지). 뺄셈은 별도 구현.

### IP 레지스터 맵 (APB, `rp*` 신호)
| Offset | Write | Read |
|--------|-------|------|
| `0x0` | x 저장 | x |
| `0x4` | y 저장 | y |
| `0x8` | z 저장 | z(결과) |
| `0xC` | fadd (x+y) | fsub (x−y) |
| `0x10`| fmult (x×y) | fdiv (x÷y) |

`IP_TOP.v`의 미완성 핵심: (1) `var_z`에 FPU 결과 반영, (2) `fpu_top` 인스턴스/연결,
(3) `rpready_set` — FPU 연산 완료 전까지 `rpready=0`으로 wait-state 생성 (APB `pready` 개념).

## 디렉터리 규약

저장소는 source-of-truth. RVX 빌드 시 `user/rtl/src`·`user/sw/src`로 복사/링크.
constraint/testbench/sim 환경은 RVX가 자동 생성하므로 저장소에 두지 않음.

- `hardware/src/` — RTL (`fpu_*.v`, `IP_TOP.v`, 신규 `fpu_top.v`) → RVX `user/rtl/src`
- `hardware/sim/` — **iverilog 로컬 검증용** testbench + run 스크립트 (Step 1)
- `software/` — C 소스(`fpu_test.c`, `k_means_oled.c`, `data_150.h`) → RVX `user/sw/src`
- `kmeans_fpu.xml` — 플랫폼 spec (저장소 루트, RVX platform xml 로 사용)

## RVX 빌드 환경 (중요)

- **RVX = 클라이언트–서버**. 학생은 special IP만 설계, 나머지 SoC·합성/구현은 RVX가 처리.
  무거운 빌드는 **서버에서 SSH 원격 실행**(`rvx_devkit.make_at_server`→`request_ssh`) → **로컬 Vivado 불필요**.
- **RVX Mini는 Linux(Debian/Ubuntu) 지원** (`rvx_install.mh`의 `check_linux:@uname`, `apt install sshpass`, `python_ubuntu` 타깃). 이 Debian box에 설치 가능.
- 서버: `cau01.rvx.coreicc.net:2022`. **계정/비밀번호는 강의에서 배부** — 저장소·문서에 평문으로 커밋 금지 (자격증명은 repo 밖에서 관리).
- 빌드 흐름: `make sync → (platform) make new/edit xml → make syn → make sim_rtl → make <app>.sim → make arty-50 → make imp(.bit)`. `make program`은 플래시(보드 필요).
- 이 환경 도구: **iverilog/vvp 있음**(Step1 로컬 검증 가능), **Vivado 없음**(불필요), RVX Mini 미설치(설치 예정).

## 작업/환경 메모

- **경로에 한글·공백 포함**: 셸에서 한글 파일명을 리터럴로 다루면 NFC/NFD 정규화로 실패할 수 있다.
  glob(`for f in *.v`)이나 따옴표를 쓰고, Read 도구에는 절대경로를 사용.
- `k_means_oled.c` 시뮬 시 권장 파라미터: `num_data 5`, `use_oled 0`, `full_printf 0` (FPGA는 100).
- FPGA: Arty A7-50 + Pmod OLED RGB (JA), OLIMEX JTAG. 앱 출력은 UART/PuTTY.

## 현재 상태

- **Step 1 완료**: `fpu_top.v`(adder/mult/divider 각 1개, fsub=부호반전, `done` 출력) + `tb_fpu_top.v` — iverilog/Questa 로컬 검증 PASS.
- **Step 2 RTL 완료**: `IP_TOP.v` 빈칸 작성(busy/start-pulse FSM, `op_serviced`, rpready wait-state) + `tb_ip_top.v`(APB 마스터) — iverilog/Questa 로컬 검증 PASS.
- **이후 작업은 RVX가 설정된 Windows 환경에서 진행**: `make syn`/`sim_rtl`/`<app>.sim`/`imp`/`program`, 그리고 Step 3(`k_means_oled.c` FPU API 적용).
- 로컬 EDA 설치(Questa/Vivado on this Debian box)는 시도했으나 컨테이너 MAC 변경으로 라이선스 불안정 → **Windows RVX 환경으로 전환**.

검증 없이 "동작한다"고 단정하지 말 것 — iverilog/Questa 또는 RVX 시뮬레이션 결과로 확인한 사실만 보고.
