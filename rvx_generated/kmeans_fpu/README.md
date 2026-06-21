# RVX `kmeans_fpu` 플랫폼 산출물 (생성/편집 파일 스냅샷)

RVX(`C:\rvx_lec_hw\platform\kmeans_fpu`)에서 빌드한 결과를 제출/보관용으로 복사해 둔 것이다.
저장소의 source-of-truth는 `hardware/src/`·`software/`이며, 이 폴더는 RVX가 생성하거나
RVX 안에서 편집한 파일의 스냅샷이다.

## 구성

- `kmeans_fpu.xml` — 플랫폼 명세 (저장소 루트 `kmeans_fpu.xml`과 동일, 메인코어 ORCA + `i_test1`=user_slaveif_apb_clkin)
- `user/rtl/src/*.v` — special IP RTL (`hardware/src/`에서 복사: IP_TOP, fpu_top, fpu_adder/multiplier/divider)
- `user/rtl/include/kmeans_fpu_user_region.vh` — **글루코드**. RVX가 `make syn`으로 생성한 템플릿을
  `IP_TOP` 인스턴스로 연결(uNoC ↔ special IP). 이 프로젝트의 핵심 수작업 파일.
- `user/sim/include/sim_user_region.vh`, `user/env/*` — RVX 생성 시뮬/환경 파일
- `user/template/*` — RVX가 생성한 원본 템플릿(참고용)
- `app/{fpu_test,k_means_oled,k_means_base}/` — RTL 시뮬에 사용한 앱 소스
  - `fpu_test` : Step 2 사칙연산 검증 앱
  - `k_means_oled` : Step 3 FPU API 적용 K-means (제출 대상, 저장소 `software/k_means_oled.c`와 동일 로직)
  - `k_means_base` : 가속 비교용 baseline(소프트웨어 float). 비교 측정 전용
- `bitstream/kmeans_fpu_fpga.arty-50.bit` — Arty S7-50(Spartan-7 xc7s50csga324-1) 비트스트림 (`make imp` 산출물)

## i_test1 (FPU IP) 레지스터 맵 — base `0xE2020000`

| Offset | Write | Read |
|--------|-------|------|
| 0x0 | x | x |
| 0x4 | y | y |
| 0x8 | z | z(결과) |
| 0xC | fadd (x+y) | fsub (x−y) |
| 0x10| fmult (x×y) | fdiv (x÷y) |

## 검증 결과 (RVX RTL 시뮬, 2026-06-21)

- **Step 2 (fpu_test)** x=14.53, y=87.91 → fadd 102.44 / fsub −73.38 / fmult 1277.33 / fdiv 0.165283. Errors 0.
- **Step 3 (k_means_oled, num_data=5)** 군집 결과가 소프트웨어 버전과 동일:
  means (76.50,16.00)/(48.00,39.00)/(50.00,49.50), 2 iterations, group 2/1/2.
- **가속(profiling tick, full_printf=0, num_data=5)** clustering 루프: baseline 7057 → FPU 2880 (≈2.45×).
- **FPGA 구현** `make imp` 성공: DRC 0 Errors, **Timing: Success**, Bitgen 성공(0 Critical Warnings).

> FPGA 보드 동작 확인(`make program` → `make printf`)은 Arty S7-50 + OLIMEX JTAG 연결 시 진행.
