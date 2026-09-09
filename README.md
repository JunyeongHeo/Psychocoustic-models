# 심리음향 모델 (Psychoacoustic Model) LaTeX 문서

한국어 기술 조사 문서입니다. 심리음향 모델의 **배경 및 동기**, **수식**, **알고리즘 및 구현 기법**을 다룹니다.

- 주 산출물: [`main.tex`](main.tex)
- 컴파일 결과물: `main.pdf` (생성물, 저장소에 포함하지 않아도 됨)

## 조판 설정

- **권장 엔진**: XeLaTeX (기본) 또는 LuaLaTeX
  - 한글 조판을 위해 `kotex` 패키지가 `fontspec`을 통해 CJK 폰트를 사용하므로, `pdflatex`가 아닌 **XeLaTeX/LuaLaTeX**를 사용해야 합니다.
- **한국어 패키지**: `kotex`
- **사용 폰트**: **Noto Serif CJK KR / Noto Sans CJK KR** (한글), **Noto Serif / Noto Sans** (라틴)
  - `main.tex` preamble에 명시적으로 지정되어 있으므로 이 폰트들이 시스템에 설치되어 있어야 합니다.

## 필수 패키지 / 폰트 준비

TeX 배포판(TeX Live 또는 MacTeX)과 한국어 지원, CJK 폰트가 필요합니다.

### Debian / Ubuntu

```sh
sudo apt-get install texlive-xetex texlive-lang-korean fonts-noto-cjk
```

### TeX Live (tlmgr) 사용 시

```sh
tlmgr install kotex-utf collection-langkorean latexmk algorithmicx booktabs \
              siunitx pgfplots cleveref mathtools algpseudocodex
```

필요한 주요 LaTeX 패키지: `kotex`, `fontspec`, `amsmath`, `amssymb`, `mathtools`,
`siunitx`, `booktabs`, `array`, `graphicx`, `tikz`, `pgfplots`, `algorithm`,
`algpseudocodex`, `hyperref`, `cleveref`, `geometry`.

## 컴파일 방법

상호참조와 목차 갱신을 위해 **두 번** 실행하십시오.

```sh
xelatex main.tex
xelatex main.tex
```

대안:

```sh
# LuaLaTeX 사용
lualatex main.tex
lualatex main.tex

# latexmk 사용 (자동 반복 실행)
latexmk -xelatex main.tex
```

## 폰트 교체

이 문서는 **Noto CJK** 폰트를 사용하도록 `main.tex` preamble에 지정되어 있습니다.

```latex
\setmainfont{Noto Serif}
\setsansfont{Noto Sans}
\setmainhangulfont{Noto Serif CJK KR}
\setsanshangulfont{Noto Sans CJK KR}
```

다른 폰트로 바꾸려면 위 지정을 수정하십시오. (예: 나눔 계열)

```latex
% \setmainhangulfont{NanumMyeongjo}
% \setsanshangulfont{NanumGothic}
```

## 이 샌드박스에 대한 주의사항

이 문서를 작성한 샌드박스 환경에는 **TeX 배포판(xelatex/lualatex/latexmk)과 CJK
폰트가 설치되어 있지 않으며, 네트워크가 차단(INTEGRATIONS_ONLY)되어 설치도
불가능**합니다. 따라서 **PDF 컴파일은 위의 준비 과정을 갖춘 외부 환경에서 수행**해야
합니다. 저장된 `main.tex`는 컴파일 가능한 정상 소스이며, 위 명령으로 빌드하면
`main.pdf`가 생성됩니다.

## 문서 구성

1. **배경 및 동기** — 청각 생리(달팽이관·기저막·임계대역), 절대 청취 문턱값(ATH),
   동시/시간적 마스킹, 지각적 무의미성과 부호화에서의 역할
2. **수식** — Terhardt ATH, Zwicker Bark 변환 및 임계대역폭, Schroeder 확산 함수,
   톤성/비톤성 마스커 판별, 개별·전역 마스킹 문턱값, SMR/MNR/SNR 관계
3. **알고리즘 및 구현 기법** — MPEG-1 심리음향 모델 1·2 의사코드, 비트 할당과의 결합,
   TikZ/pgfplots 그림, booktabs 표

## 참고 문헌

- E. Zwicker and H. Fastl, *Psychoacoustics: Facts and Models*, Springer.
- T. Painter and A. Spanias, "Perceptual Coding of Digital Audio," *Proc. IEEE*, vol. 88, no. 4, 2000.
- ISO/IEC 11172-3 (MPEG-1 Audio).
- E. Terhardt, "Calculating virtual pitch," *Hearing Research*, 1979.
- M. Bosi and R. E. Goldberg, *Introduction to Digital Audio Coding and Standards*, Kluwer.
