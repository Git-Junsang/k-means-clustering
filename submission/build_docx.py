# -*- coding: utf-8 -*-
"""보고서.docx 생성. 제출물 안내 요구사항만 작성. 코드는 필요한 부분만 1x1 표(박스)에.
설명은 번호+문장. 캡쳐가 필요한 곳은 빈 박스 + 방법."""
import sys
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

REPO = r'C:\k-means-clustering'
doc = Document()
st = doc.styles['Normal']; st.font.name='Malgun Gothic'; st.font.size=Pt(10.5)
st.element.rPr.rFonts.set(qn('w:eastAsia'),'Malgun Gothic')

def _kfont(r, name='Malgun Gothic', size=None):
    r.font.name=name
    if size: r.font.size=Pt(size)
    r.element.rPr.rFonts.set(qn('w:eastAsia'), name)

def H(text, lvl=1):
    h=doc.add_heading(text, level=lvl)
    for r in h.runs: _kfont(r); r.font.color.rgb=RGBColor(0,0,0)

def P(text='', bold=False, italic=False):
    p=doc.add_paragraph(); r=p.add_run(text); r.bold=bold; r.italic=italic; _kfont(r); return p

def NUM(items):
    """번호 + 문장 (불릿 대신)."""
    for i, t in enumerate(items, 1):
        P('%d. %s' % (i, t))

def CMD(text):
    """명령어 한두 줄 (작은 monospace, 박스 아님)."""
    p=doc.add_paragraph(); p.paragraph_format.left_indent=Cm(0.4); p.paragraph_format.space_after=Pt(3)
    for i,l in enumerate(text.split('\n')):
        if i: p.add_run().add_break()
        r=p.add_run(l); _kfont(r,'Consolas',9.5)

def _code_lines(path, start, end):
    lines=open(path, encoding='utf-8').read().replace('\r','').split('\n')
    def idx(m,d):
        if m is None: return d
        if isinstance(m,int): return m-1
        for i,l in enumerate(lines):
            if m in l: return i
        return d
    return lines[idx(start,0):idx(end,len(lines)-1)+1]

def CODEBOX(text=None, path=None, start=None, end=None, caption=None):
    """코드(필요 부분)를 1x1 표 안에 넣는다."""
    if caption:
        p=doc.add_paragraph(); r=p.add_run(caption); r.bold=True; _kfont(r, size=9.5)
    if path is not None:
        text='\n'.join(_code_lines(path, start, end))
    t=doc.add_table(rows=1, cols=1); t.style='Table Grid'
    cell=t.rows[0].cells[0]; p=cell.paragraphs[0]; p.paragraph_format.space_after=Pt(0)
    for i,line in enumerate(text.split('\n')):
        if i: p.add_run().add_break()
        r=p.add_run(line); _kfont(r,'Consolas',8.5)
    doc.add_paragraph()

def CAPTURE(title, h_cm=5.0):
    p=doc.add_paragraph(); r=p.add_run(title); r.bold=True; _kfont(r)
    t=doc.add_table(rows=1, cols=1); t.style='Table Grid'
    tr=t.rows[0]._tr; trPr=tr.get_or_add_trPr()
    e=OxmlElement('w:trHeight'); e.set(qn('w:val'), str(int(h_cm*567))); e.set(qn('w:hRule'),'atLeast'); trPr.append(e)
    cell=t.rows[0].cells[0]; pr=cell.paragraphs[0]; pr.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=pr.add_run('(여기에 캡쳐 이미지 삽입)'); r.italic=True; r.font.color.rgb=RGBColor(0x88,0x88,0x88); _kfont(r,size=9)

def HOWP(text):
    p=doc.add_paragraph(); r=p.add_run('캡쳐 방법: '); r.bold=True; _kfont(r)
    r2=p.add_run(text); _kfont(r2)

def TABLE(headers, rows):
    t=doc.add_table(rows=1, cols=len(headers)); t.style='Table Grid'
    for i,htxt in enumerate(headers):
        c=t.rows[0].cells[i]; rr=c.paragraphs[0].add_run(htxt); rr.bold=True; _kfont(rr,size=10)
    for row in rows:
        cells=t.add_row().cells
        for i,v in enumerate(row):
            rr=cells[i].paragraphs[0].add_run(str(v)); _kfont(rr,size=10)
    doc.add_paragraph()

IP=REPO+r'\hardware\src\IP_TOP.v'
FT=REPO+r'\hardware\src\fpu_top.v'
TB=REPO+r'\hardware\sim\tb_fpu_top.v'
GLUE=REPO+r'\rvx_generated\kmeans_fpu\user\rtl\include\kmeans_fpu_user_region.vh'
KM=REPO+r'\software\k_means_oled.c'

# ===================== TITLE =====================
H('K-means clustering을 위한 FPU IP 설계 — 보고서', 0)
P('학번 / 이름 : __________ (작성 필요)')
P('플랫폼 : RVX kmeans_fpu, FPGA : Arty S7-50 (Spartan-7 xc7s50csga324-1), Pmod OLED RGB, OLIMEX ARM-USB-TINY-H JTAG.')

# ===================== STEP 1 =====================
H('Step 1. FPU 모듈 동작 확인 (RTL Simulation)', 1)
P('IEEE-754 단정밀도 FPU 모듈(adder/multiplier/divider)을 이용해 사칙연산을 제어하는 fpu_top.v를 작성하고, '
  '테스트벤치로 fadd/fsub/fmult/fdiv 결과를 IEEE-754 기대값과 비교하여 RTL 시뮬레이션으로 검증하였다.')

H('1.1 작성한 코드 (fpu_top.v 핵심)', 2)
P('덧셈/곱셈/나눗셈은 각 모듈을 하나씩만 인스턴스화하고, 뺄셈은 x − y = x + (−y) 이므로 피연산자 b의 '
  '부호비트를 반전하여 가산기로 처리한다. 아래는 연산 선택(FSM) 부분이다.')
CODEBOX(path=FT, start=110, end=140)
P('세 모듈은 각각 하나씩만 인스턴스화한다(중복 없음).')
CODEBOX(path=FT, start=147, end=166)

H('1.2 작성한 코드 (testbench 핵심)', 2)
P('테스트벤치는 x=14.53, y=87.91을 입력하고 4개 연산을 차례로 요청한 뒤 var_z를 기대값과 비교한다.')
CODEBOX(path=TB, start='$display("=== fpu_top', end="do_op(4'b1000")

H('1.3 시뮬레이션 결과', 2)
P('4종 연산이 모두 IEEE-754 기대값과 일치하였다(아래 값).')
TABLE(['연산','결과','hex'],
      [['fadd (x+y)','102.44','0x42CCE148'],
       ['fsub (x-y)','-73.38','0xC292C290'],
       ['fmult (x*y)','1277.33','0x449FAAA2'],
       ['fdiv (x/y)','0.165283','0x3E293FDC']])
CAPTURE('[캡쳐 1] 시뮬레이션 결과')
P('캡쳐 방법은 콘솔 결과 또는 파형 중 하나를 사용한다.', italic=True)
P('1. 콘솔 결과 — PowerShell에서 아래를 실행하면 4종 연산 PASS와 결과가 출력된다.')
CMD('cd C:\\k-means-clustering\\hardware\\sim\n.\\run.ps1')
P('2. 파형 — 아래를 실행하면 QuestaSim에 var_x/var_y/var_z가 float32로 표시되고 run·Zoom Full 된 파형이 뜬다.')
CMD('cd C:\\k-means-clustering\\hardware\\sim\nvsim -do wave_fpu_top.do')

# ===================== STEP 2 =====================
H('Step 2. FPU 모듈을 적용한 IP 설계 (FPGA Prototyping)', 1)
P('fpu_top을 APB 슬레이브 IP(IP_TOP.v)에 통합하여 ORCA 프로세서에 연결하고, 사칙연산 테스트 앱 fpu_test.c로 '
  'FPGA에서 동작을 검증하였다. IP의 i_test1 슬레이브 base 주소는 0xE2020000 이다.')

H('2.1 IP_TOP.v 작성한 부분', 2)
P('레지스터 맵은 0x0=x, 0x4=y, 0x8=z(결과), 0xC(쓰기=fadd / 읽기=fsub), 0x10(쓰기=fmult / 읽기=fdiv) 이다. '
  '작성한 핵심은 다음 네 가지이다.')
NUM([
 'FPU 연동 신호 선언(결과/완료/요청 펄스/busy 등).',
 'FPU 연산 완료(fpu_done) 시 결과를 z 레지스터에 반영.',
 '레벨로 유지되는 요청을 1-cycle 시작 펄스로 변환하는 busy FSM과 fpu_top 인스턴스(op_serviced로 재트리거 방지).',
 '연산 주소 접근 중 결과가 나올 때까지 rpready=0으로 APB wait-state 생성.',
])
CODEBOX(path=IP, start=53, end=60, caption='① FPU 연동 신호')
CODEBOX(path=IP, start=135, end=143, caption='② var_z에 FPU 결과 반영')
CODEBOX(path=IP, start=147, end=196, caption='③ 시작펄스/busy FSM + fpu_top 인스턴스')
CODEBOX(path=IP, start=200, end=207, caption='④ rpready wait-state')
P('이 IP를 RVX uNoC(APB)에 연결하는 글루코드(i_test1 = IP_TOP 인스턴스)는 다음과 같다.')
CODEBOX(path=GLUE, start='IP_TOP', end=');', caption='글루코드 (kmeans_fpu_user_region.vh)')

H('2.2 실행 결과 (PuTTY)', 2)
P('FPGA에서 fpu_test 실행 결과, x=14.53 / y=87.91에 대해 fadd 102.44, fsub −73.38, fmult 1277.33, '
  'fdiv 0.17(소수 2자리 출력)로 기대값과 일치하였다.')
CAPTURE('[캡쳐 2] fpu_test 실행결과 (PuTTY)')
HOWP('imp 디렉터리에서 make program 으로 비트스트림을 올린 뒤, PuTTY를 COM5/115200으로 연결하고 '
     '다른 창에서 make fpu_test.run 을 실행하면 PuTTY에 위 결과가 출력된다.')
CMD('cd C:\\rvx_lec_hw\\platform\\kmeans_fpu\\imp_arty-50_2026-06-21\nmake program\nmake fpu_test.run')

H('2.3 FPGA 보드 사진', 2)
CAPTURE('[캡쳐 3] FPGA 보드 + PuTTY 창 + 메모장(이름/학번)', h_cm=6.0)
HOWP('동작 중인 Arty S7-50 보드와 PuTTY 실행결과 창, 그리고 본인 이름·학번을 적은 메모장이 한 화면(또는 한 사진)에 '
     '모두 나오도록 촬영한다.')

# ===================== STEP 3 =====================
H('Step 3. K-means clustering에 IP 적용 (FPGA Prototyping)', 1)
P('K-means 응용의 소프트웨어 실수 연산을 설계한 FPU IP의 API로 대체하고, 군집 결과가 소프트웨어와 동일한지와 '
  'FPU 적용 전·후 가속효과를 확인하였다.')

H('3.1 API로 대체한 부분', 2)
P('fpu_test.c의 set_x/set_y/get_z 패턴으로 fpu_add/fpu_sub/fpu_mult/fpu_div(a,b) 래퍼를 만들어 사용하였다.')
CODEBOX(path=KM, start='static inline float fpu_add', end='static inline float fpu_div', caption='FPU 연산 래퍼')
P('k_means_oled.c에서 실수 연산 네 곳을 아래와 같이 대체하였다(사칙연산 4종 모두 사용).')
CODEBOX(text=(
 '// (1) 거리계산 sqr((float)data - means) : fsub, fmult, fadd\n'
 'float diff = fpu_sub((float)data[i][l], means[j][l]);\n'
 'float sq   = fpu_mult(diff, diff);\n'
 'dis        = fpu_add(dis, sq);\n'
 '// (2) 새 mean 누적 : fadd\n'
 'temp[group[i]][j] = fpu_add(temp[group[i]][j], (float)data[i][j]);\n'
 '// (3) 평균 : fdiv\n'
 'temp[i][j] = fpu_div(temp[i][j], (float)count[i]);\n'
 '// (4) 수렴 판정 뺄셈 : fsub\n'
 'if(ABS(fpu_sub(temp[i][j], means[i][j])) > 0.0001)'), caption='대체한 4곳')

H('3.2 실행 결과 (PuTTY)', 2)
P('FPGA에서 데이터 100점에 대해 군집화가 3 iterations만에 수렴하였고, 세 클러스터의 데이터 수는 35 / 29 / 36 '
  '(합 100), 최종 means는 (70.43, 18.23), (19.72, 35.90), (54.08, 49.14) 였다. '
  '소프트웨어 버전과 동일한 군집 결과로, IP가 올바르게 동작함을 확인하였다.')
CAPTURE('[캡쳐 4] k_means_oled 실행결과 (PuTTY)')
HOWP('PuTTY(COM5/115200) 연결 상태에서 make k_means_oled.run 을 실행하면 PuTTY에 위 군집 결과가 출력된다.')
CMD('cd C:\\rvx_lec_hw\\platform\\kmeans_fpu\\imp_arty-50_2026-06-21\nmake k_means_oled.run')

H('3.3 FPU 적용 전·후 가속효과 비교', 2)
P('동일 조건(num_data=5, 루프 내 printf 제외)에서 clustering 루프의 profiling tick을 비교하면, 소프트웨어 float '
  '대비 FPU 적용 시 약 2.45배 단축되었다(가속 정도 자체는 평가 대상 아님).')
TABLE(['구분','측정 앱','total tick','time(ms)'],
      [['FPU 적용 전 (소프트웨어 float)','k_means_base','7057','7.06'],
       ['FPU 적용 후 (FPU IP)','k_means_fpu','2880','2.88']])
CAPTURE('[캡쳐 5] 가속효과 비교 (profiling tick)')
P('측정 전용 앱 두 개(k_means_fpu, k_means_base)는 비교가 공정하도록 full_printf=0, num_data=5로 '
  '미리 맞춰 두었다(편집 불필요). k_means_oled.c 자체는 수정하지 않는다.', italic=True)
HOWP('sim_rtl에서 아래 두 명령을 실행하면 각 출력의 [section] K-means clustering 의 total tick이 나온다. '
     'k_means_fpu = 2880(FPU 적용 후), k_means_base = 7057(적용 전 소프트웨어).')
CMD('cd C:\\rvx_lec_hw\\platform\\kmeans_fpu\\sim_rtl\nmake k_means_fpu\nmake k_means_base')

H('3.4 FPGA 보드 사진', 2)
CAPTURE('[캡쳐 6] FPGA 보드 + PuTTY 창 + 메모장(이름/학번)', h_cm=6.0)
HOWP('Step 2의 [캡쳐 3]과 동일한 방식으로 촬영하며, 같은 사진을 사용해도 된다.')

out = sys.argv[1] if len(sys.argv) > 1 else REPO+r'\submission\보고서.docx'
doc.save(out)
print('saved:', out)
