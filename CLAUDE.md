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

| 파일　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　| 규칙　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| -------------------------------------------------------------------| ----------------------------------------------------------------------------------------|
| `kmeans_fpu/rtl/fpu_adder.v`, `fpu_multiplier.v`, `fpu_divider.v` | **수정 금지.** dawsonjon/fpu 라이브러리. git에서 직접 받지 말고 첨부된 파일을 instance |
| `kmeans_fpu/rtl/IP_TOP.v`　　　　　　　　　　　　　　　　　　　　 | 주석 처리된 `Please fill in...` 빈칸만 작성. **그 외 부분 수정 금지**　　　　　　　　　|
| `kmeans_fpu/kmeans_fpu.xml`　　　　　　　　　　　　　　　　　　　 | **수정 금지.** 플랫폼 명세 그대로 사용　　　　　　　　　　　　　　　　　　　　　　　　 |
| `kmeans_fpu/app/fpu_test.c`　　　　　　　　　　　　　　　　　　　 | **수정 금지.** Step 2 검증용　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| `kmeans_fpu/app/k_means_oled.c`　　　　　　　　　　　　　　　　　 | Step 3에서 실수 연산을 FPU API로 대체 (수정 대상)　　　　　　　　　　　　　　　　　　　|
| `kmeans_fpu/rtl/fpu_top.v`, `testbench.v`　　　　　　　　　　　　 | **신규 작성** (아직 없음)　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　|

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

## 작업/환경 메모

- **경로에 한글·공백 포함**: 셸에서 한글 파일명을 리터럴로 다루면 NFC/NFD 정규화로 실패할 수 있다.
  glob(`for f in *.v`)이나 따옴표를 쓰고, Read 도구에는 절대경로를 사용.
- RTL 시뮬레이터: Questa/Vivado. 파형의 float 신호는 Radix를 `float32`로.
- FPGA: Arty A7 + Pmod OLED RGB (포트 JA). 앱 출력은 UART/PuTTY.
- `k_means_oled.c` 시뮬 시 권장 파라미터: `num_data 5`, `use_oled 0`, `full_printf 0` (FPGA는 100).
- 빌드/플랫폼 생성은 RVX 프레임워크 절차를 따름 (이 저장소엔 RTL/앱 소스만 존재).

## 현재 상태

git 저장소이며 아직 커밋 없음. 모든 파일이 untracked. 스켈레톤 단계.
검증 없이 "동작한다"고 단정하지 말 것 — RTL 시뮬레이션/FPGA 결과로 확인한 사실만 보고.
