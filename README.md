# K-means Clustering을 위한 FPU IP 설계

중앙대학교 **디지털회로 및 시스템 설계** 과제 프로젝트 (이우주 교수님 연구실 / Low Power SoC Lab.)

경량 정수형 RISC-V 코어(ORCA, RVX 플랫폼) 위에서 동작하는 K-means clustering 응용을
**하드웨어 FPU(Floating Point Unit) IP**로 가속하는 프로젝트입니다.

---

## 1. 배경

- **K-means clustering**: 정답 레이블을 사용하지 않는 비지도 학습(Unsupervised Learning)으로,
  데이터를 K개의 클러스터로 군집화한다. 매 iteration마다 새로운 군집 중심값(mean)을 도출하며,
  이 과정에서 **실수(부동소수점) 연산**이 반복적으로 사용된다.
- **문제점**: 본 프로젝트의 메인 코어는 경량 정수형 코어인 **ORCA 코어**로, 실수 연산을 수행하는
  FPU가 없다. 따라서 실수 연산이 소프트웨어 에뮬레이션으로 처리되어 **매우 느리다**.
- **해결**: IEEE-754 단정밀도(single precision) FPU 모듈을 **APB 슬레이브 IP**로 설계하여
  프로세서에 연결하고, K-means 응용의 실수 연산을 이 IP로 오프로딩하여 **연산 속도를 높인다**.

사용하는 FPU Verilog 라이브러리: [dawsonjon/fpu](https://github.com/dawsonjon/fpu)
("Synthesiseable IEEE 754 floating point library in Verilog", MIT License).
`adder`, `divider`, `multiplier` 코드를 RVX 환경에 맞게 수정한 버전이 포함되어 있다.

---

## 2. 디렉터리 구조

이 저장소는 **source-of-truth**이고, RVX 빌드 시에는 아래 파일을 RVX 플랫폼의
`user/rtl/src`, `user/sw/src`로 **복사(또는 심볼릭 링크)**해서 사용한다. constraint·testbench·sim
환경은 **RVX가 자동 생성**하므로 저장소에 따로 두지 않는다.

```
k-means-clustering/
├── documents/                     # 프로젝트/제출물 안내 PDF
├── kmeans_fpu.xml                 # RVX 플랫폼 명세 (→ platform 의 tip_xxx.xml)
├── hardware/
│   ├── src/                       # RTL 소스 → RVX의 user/rtl/src 로 복사
│   │   ├── fpu_adder.v            # IEEE754 가산기   (수정 X)
│   │   ├── fpu_multiplier.v       # IEEE754 곱셈기   (수정 X)
│   │   ├── fpu_divider.v          # IEEE754 나눗셈기 (수정 X)
│   │   ├── IP_TOP.v               # APB 슬레이브 IP top — 빈칸 채워서 완성 (Step 2)
│   │   └── fpu_top.v              # (신규 작성, Step 1) FPU 사칙연산 제어 top
│   └── sim/                       # iverilog 로컬 검증용 testbench + run 스크립트 (Step 1)
└── software/                      # C 소스 → RVX의 user/sw/src 로 복사
    ├── fpu_test.c                 # Step 2 사칙연산 테스트 앱 (수정 X)
    ├── k_means_oled.c             # K-means clustering 응용 (Step 3에서 수정)
    └── data_150.h                 # 입력 데이터 data[150][2]
```

> **아직 생성되지 않은 파일**: `hardware/src/fpu_top.v`(Step 1), `hardware/sim/`의 testbench 는 직접 작성해야 한다.
> constraint/testbench/sim 환경은 RVX의 `make syn`/`make testbench`/`make sim_rtl`이 생성하므로 별도 폴더를 두지 않는다.

### FPU 모듈 인터페이스 (수정 금지)

세 모듈(`fpu_adder` / `fpu_multiplier` / `fpu_divider`)은 동일한 포트와 handshake 프로토콜을 가진다.

| 포트 | 방향 | 폭 | 설명 |
|------|------|-----|------|
| `clk`, `rstnn` | in | 1 | 클럭 / active-low 리셋 |
| `input_a`, `input_b` | in | 32 | 피연산자 |
| `input_a_stb`, `input_b_stb` | in | 1 | 입력 데이터 준비됨 (strobe) |
| `input_a_ack`, `input_b_ack` | out | 1 | 입력 수신 완료 (ack) |
| `output_z` | out | 32 | 결과값 |
| `output_z_stb` | out | 1 | 결과 준비됨 |
| `output_z_ack` | in | 1 | 결과 수신 완료 |

- **`XX_stb`**: 데이터 전송 전 발생, "데이터가 준비되었음".
- **`XX_ack`**: 데이터 수신 후 발생, "성공적으로 수신했음".
- 모든 handshake 신호를 빠짐없이 적절히 사용해야 한다.

### IP 레지스터 맵 (APB, `I_TEST1_SLAVE_BASEADDR` 기준)

| Offset | 이름 | Write 동작 | Read 동작 |
|--------|------|-----------|-----------|
| `0x0`  | X | 피연산자 x 저장 | x 반환 |
| `0x4`  | Y | 피연산자 y 저장 | y 반환 |
| `0x8`  | Z | 결과 z 저장 | z(연산 결과) 반환 |
| `0xC`  | FADD/FSUB | **fadd** 요청 (x+y→z) | **fsub** 요청 (x−y→z) |
| `0x10` | FMULT/FDIV | **fmult** 요청 (x×y→z) | **fdiv** 요청 (x÷y→z) |

> 즉 `write 0xC` = 덧셈, `read 0xC` = 뺄셈, `write 0x10` = 곱셈, `read 0x10` = 나눗셈.
> APB 버스 신호는 `rp*` 접두사(`rpsel`, `rpenable`, `rpaddr`, `rpwrite`, `rpwdata`, `rprdata`, `rpready`, `rpslverr`).

---

## 3. 프로젝트 단계 (Phases & Tasks)

전체 흐름: **Step 1 (FPU 동작 확인) → Step 2 (IP 설계) → Step 3 (실제 앱 적용)**.
각 단계는 RTL Simulation으로 검증하고, Step 2~3은 FPGA(Arty A7 + Pmod OLED RGB) 프로토타이핑까지 진행한다.

### Phase 1 — FPU 모듈 동작 확인 (RTL Simulation)

목표: 제공된 IEEE754 FPU 모듈의 사용법을 익히고, 사칙연산 제어 로직(`fpu_top.v`)의 최소 동작을 검증한다.

- [x] **T1.1** `fpu_adder.v` / `fpu_multiplier.v` / `fpu_divider.v` 의 handshake(stb/ack FSM) 프로토콜 분석
- [x] **T1.2** `fpu_top.v` 작성 — 입력 `clk, rstnn, var_x, var_y, request_fadd/fsub/fmult/fdiv` (8개),
      출력 `var_z` (1개). adder/mult/divider **각 1개씩** 인스턴스. **fsub는 b 부호비트 반전**으로 구현(`x-y=x+(-y)`).
- [x] **T1.3** `hardware/sim/tb_fpu_top.v` 작성 — request별 사칙연산 결과를 IEEE754 기대값과 비교
- [x] **T1.4** **iverilog 로컬 검증 통과** (`./hardware/sim/run.sh`): fadd/fsub/fmult/fdiv 4종 모두 PASS
      (x=14.53, y=87.91 → 102.44 / -73.38 / 1277.33 / 0.165283). RVX/Questa 파형은 Radix `float32`로 확인.
- [ ] **T1.5** (제출) 보고서: `fpu_top.v`, `testbench` 코드, 시뮬레이션 결과 캡쳐 + 코드/결과 설명

**검증되는 것**: FPU Adder/Multiplier/Divider 사용법, 사칙연산 제어 로직의 최소 동작.
**아직 불확실한 것**: 다른 앱에서도 동작할지, synthesizable 한지, FPGA에서 동작할지.

### Phase 2 — FPU 모듈을 적용한 IP 설계 (RTL Sim + FPGA Prototyping)

목표: `fpu_top`을 APB 슬레이브 IP(`IP_TOP.v`)에 통합하여 프로세서와 연결하고, 사칙연산 테스트 앱을 실행한다.

- [ ] **T2.1** `IP_TOP.v` 의 빈칸(`Please fill in the relevant code here`) 작성
  - `var_z` write 경로 (FPU 결과를 z에 반영)
  - `fpu_top.v` 인스턴스화 및 `request_*` / `var_x,y,z` 연결 (이 단계에서 `fpu_top.v` 코드 수정 허용)
  - **`rpready_set` 로직**: FPU 연산이 끝날 때까지 충분히 대기하도록 wait-state 생성.
    AMBA **APB의 `pready`** 신호 개념 참고 ("연산 완료까지 `rpready=0` 유지").
- [ ] **T2.2** 설계한 IP를 프로세서(`i_test1` 슬레이브)에 연결
- [ ] **T2.3** `fpu_test.c` (수정 X) 실행 — x=14.53, y=87.91 에 대한 add/sub/mult/div 결과 확인
- [ ] **T2.4** RTL 시뮬레이션 및 FPGA 프로토타이핑으로 동작 확인
- [ ] **T2.5** (제출) 보고서: 작성한 `IP_TOP.v` 부분, PuTTY 실행결과 캡쳐,
      (가능 시) FPGA 보드+PuTTY+이름/학번 사진. FPGA 미완료 시 RTL 결과창(cmd/wave) 캡쳐

**검증되는 것**: IP가 APB 통신으로 SoC에 잘 연결되었는지, 사칙연산 제어 로직의 합성 가능 여부 및 FPGA 동작.

### Phase 3 — 실제 APP(K-means clustering)에 IP 적용 (RTL Sim + FPGA Prototyping)

목표: K-means 응용의 소프트웨어 실수 연산을 설계한 FPU IP의 API로 대체하고, 결과·성능을 비교한다.

- [ ] **T3.1** `fpu_test.c` 의 `set_x/set_y/get_z/perform_*` 패턴을 참고해 FPU 연산 API 정리
- [ ] **T3.2** `k_means_oled.c` 의 실수 연산을 FPU API로 대체 — **사칙연산을 모두 사용**해야 한다
  - 거리 계산의 뺄셈/곱셈/덧셈: `sqr((float)data[i][l] - means[j][l])` → fsub, fmult, fadd
  - 새 mean 누적 덧셈: `temp[group[i]][j] += (float)data[i][j]` → fadd
  - 평균 나눗셈: `temp[i][j] /= count[i]` → fdiv
- [ ] **T3.3** `k_means_oled.c` 실행 (RTL Simulation, FPGA Prototyping)
- [ ] **T3.4** FPU 미적용 버전과 **군집화 결과가 동일한지** 비교 (동일하면 IP가 올바르게 설계된 것)
- [ ] **T3.5** `profiling_start/end("K-means clustering")` 으로 **FPU 적용 전/후 가속 효과(total tick) 비교**
      (가속 정도 자체는 평가 대상 아님)
- [ ] **T3.6** (제출) 보고서: API로 대체한 부분, PuTTY 실행결과, 가속 비교, (가능 시) FPGA 사진

**앱 파라미터** (`k_means_oled.c` 상단):

| 파라미터　　　| 의미　　　　　　　　　 | RTL 권장　　　　 | FPGA　　 |
| ---------------| ------------------------| ------------------| ----------|
| `num_data`　　| 입력 데이터 수 (0~150) | 5 (sim 약 5분)　 | 100　　　|
| `use_oled`　　| OLED 출력 활성화　　　 | 0 (sim 불가)　　 | 0 또는 1 |
| `full_printf` | 전체 printf 출력　　　 | 0 (sim에서 느림) | 0 또는 1 |

---

## 4. 빌드 / 실행 환경 (RVX)

**RVX (RISC-V eXpress, ETRI)** 는 클라이언트–서버 구조의 SoC 개발 키트다.
학생은 special IP(`IP_TOP.v` + `fpu_top.v`)만 설계하고, ORCA 코어·APB 버스·NoC·OLED·UART 등
나머지 SoC와 **합성/구현은 RVX가 자동 처리**한다. 무거운 빌드는 **RVX 서버에서 SSH로 원격 실행**되므로
**로컬에 Vivado가 필요 없다** (`rvx_devkit.make_at_server` → `request_ssh`).

- **RVX Mini**: Linux(Debian/Ubuntu) 및 Windows 지원. 서버와 연동되는 최소 클라이언트.
  - 서버: `cau01.rvx.coreicc.net` / 포트 `2022` (계정·비밀번호는 강의 배부)
- **플랫폼 spec**: `kmeans_fpu.xml` (메인 코어 ORCA, 사용자 IP `user_slaveif_apb_clkin`)
- **FPGA 프로토타이핑**: Arty A7-50 + **Pmod OLED RGB**, OLIMEX ARM-USB-TINY-H JTAG
- **앱 통신**: UART / PuTTY (`make printf`)
- **로컬 기능 검증(Step 1)**: 이 저장소에서는 **iverilog/vvp**로 `fpu_top` 사칙연산을 사전 검증 가능

### RVX 빌드 흐름 (랩 PC 또는 RVX Mini 설치 환경)

```
make sync                                  # 서버 동기화
cd platform; make new PLATFORM_NAME=tip_xxx   # 플랫폼 생성 + xml 작성 (kmeans_fpu.xml 기반)
# → user/rtl/src 에 hardware/src/*.v, user/sw/src 에 software/*.c,*.h 복사
make syn                                   # RTL 생성/합성 (서버)
make testbench && make sim_rtl             # 시뮬 환경 생성
make app_list && make <app>.sim            # RTL 시뮬레이션 (fpu_test / k_means)
cd ..; make arty-50; cd imp_arty-50_*      # FPGA 구현 환경
make imp                                   # 합성+구현+bitstream(.bit)  ← "플래시 직전" 종착점
# make program                             # FPGA 플래시 (보드 필요)
# make printf                              # PuTTY serial
```

> 저장소(이 repo)는 **user 소스(RTL/앱) + 플랫폼 xml**만 보유한다. RVX 빌드 시 `user/rtl/src`·`user/sw/src`로 복사/링크해 사용한다.

---

## 5. 제출물 (단계별)

각 단계마다 `[학번이름]stepN_보고서` 와 `[학번이름]stepN_코드.zip` 제출.

| Step | 보고서　　　　　　　　　　　　　　　　　　　　　　　　　 | 코드.zip　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| ------| ----------------------------------------------------------| --------------------------------------------------------------|
| 1    | `fpu_top.v`/testbench 코드, 시뮬 결과 캡쳐 + 설명　　　　| `testbench.v`, `fpu_top.v`, `fpu_adder/multiplier/divider.v` |
| 2    | 작성한 `IP_TOP.v`, PuTTY 결과, FPGA 사진(이름/학번 포함) | `user/rtl/src` 전체 + 사용한 `fpu_test.c`　　　　　　　　　　|
| 3    | API 대체 부분, PuTTY 결과, 가속 비교, FPGA 사진　　　　　| `user/rtl/src` 전체 + 수정한 `k_means_oled.c`　　　　　　　　|

---

## 6. 진행 현황

- [x] 프로젝트 자료(스켈레톤) 확보: FPU 모듈, `IP_TOP.v` 스켈레톤, 테스트/응용 앱, 데이터
- [x] Phase 1 — `fpu_top.v` / `tb_fpu_top.v` 작성, **iverilog 로컬 검증 통과** (RVX RTL 시뮬은 추후)
- [ ] Phase 2 — `IP_TOP.v` 완성 및 `fpu_test.c` 검증 (RVX RTL + FPGA)
- [ ] Phase 3 — `k_means_oled.c` FPU API 적용 및 가속 효과 측정
