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
              siunitx pgfplots cleveref mathtools algpseudocodex listings xcolor
```

필요한 주요 LaTeX 패키지: `kotex`, `fontspec`, `amsmath`, `amssymb`, `mathtools`,
`siunitx`, `booktabs`, `array`, `graphicx`, `tikz`, `pgfplots`, `algorithm`,
`algpseudocodex`, `hyperref`, `cleveref`, `geometry`, `listings`, `xcolor`.

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
4. **MATLAB 예제 코드** — 핵심 수식(ATH, Bark 변환, 확산 함수)의 MATLAB 구현을
   `listings` 패키지로 조판하고, 실행 가능한 스크립트를 `matlab/` 디렉터리로 제공

## MATLAB / GNU Octave 예제 코드

문서의 핵심 수식을 직접 계산·시각화하는 **간단한** MATLAB 예제를 `matlab/`
디렉터리에 함께 제공합니다. 코드는 **기본(base) MATLAB 및 GNU Octave**에서 그대로
실행되며, **특수 툴박스(예: Signal Processing Toolbox)를 요구하지 않습니다**
(Hann 창도 툴박스 없이 직접 생성).

| 파일 | 내용 | 대응 수식 |
| --- | --- | --- |
| [`matlab/ath_terhardt.m`](matlab/ath_terhardt.m) | 절대 청취 문턱값(Terhardt) | eq:ath |
| [`matlab/hz2bark.m`](matlab/hz2bark.m) | Hz → Bark 척도 변환(Zwicker) | eq:bark |
| [`matlab/critical_bandwidth.m`](matlab/critical_bandwidth.m) | 임계대역폭 | eq:cbw |
| [`matlab/spreading_function.m`](matlab/spreading_function.m) | Schroeder 2-기울기 확산 함수 | eq:spread |
| [`matlab/demo_psychoacoustic.m`](matlab/demo_psychoacoustic.m) | 구동 스크립트(FFT·SPL 정규화·마스킹 문턱값·SMR) | eq:psd, eq:global, eq:smr |
| [`matlab/pam2_unpredictability.m`](matlab/pam2_unpredictability.m) | PAM-2 불예측성 측도 c(w) | eq:pam2unpred |
| [`matlab/pam2_threshold.m`](matlab/pam2_threshold.m) | PAM-2 분할별 마스킹 문턱값·SMR (톤성·요구 SNR·ATH 하한·사전 반향) | eq:tonality, eq:snrreq, eq:nb |
| [`matlab/pam2_demo.m`](matlab/pam2_demo.m) | PAM-2 구동 스크립트(연속 프레임 합성 + 2-프레임 이력) | — |

### 실행 방법

`matlab/` 디렉터리로 이동한 뒤 구동 스크립트를 실행합니다.

```sh
# GNU Octave (헤드리스)
cd matlab
octave --no-gui demo_psychoacoustic.m
octave --no-gui pam2_demo.m          # MPEG-1 심리음향 모델 2 데모
```

```matlab
% MATLAB
cd matlab
run demo_psychoacoustic.m
run pam2_demo.m                      % MPEG-1 심리음향 모델 2 데모
```

스크립트는 ATH 곡선, 확산 함수, 스펙트럼·마스킹 문턱값 그림을 PNG(`fig_ath.png`,
`fig_spread.png`, `fig_masking.png`)로 저장하고, 검출된 톤성 정점과 대역별 SMR을
콘솔에 출력합니다. 그래픽 백엔드가 없는 환경에서는 그림 생성을 건너뛰고 수치
결과만 출력하도록 안전하게 처리되어 있습니다.

### LaTeX 리스팅 패키지

MATLAB 코드를 문서(`main.tex`)에 싣기 위해 `listings`와 `xcolor` 패키지를
추가했습니다(`minted`는 shell-escape와 Pygments가 필요하여 사용하지 않았습니다).
`tlmgr` 사용 시 다음을 함께 설치하십시오.

```sh
tlmgr install listings xcolor
```

### 이 샌드박스에 대한 주의사항 (MATLAB/Octave)

이 문서를 작성한 샌드박스에는 **MATLAB/Octave가 설치되어 있지 않고 네트워크가
차단(INTEGRATIONS_ONLY)되어 설치도 불가능**하므로, `.m` 스크립트는 **샌드박스
안에서 실행되지 않았습니다**. 위 스크립트는 기본 MATLAB/Octave에서 실행하도록
작성된 정상 소스이며, 실행은 위 준비를 갖춘 **외부 환경**에서 수행하십시오.

## PyTorch 학습 손실 (Python)

PAM-2 전역 마스킹 문턱값을 신경망 오디오 부호화기의 **학습 손실**로 활용하는
참조 구현을 `python/` 디렉터리에 제공합니다. 이 코드는 `cocosci/pam-nac`의
TensorFlow 원본 `smr_loss`·`nmr_max_mean_loss`를 관용적인 **PyTorch**로 옮긴
것으로, `torch` 외의 외부 패키지에 의존하지 않습니다.

| 파일 | 내용 | 대응 수식 |
| --- | --- | --- |
| [`python/torch_pam2_loss.py`](python/torch_pam2_loss.py) | PyTorch SMR 우선순위 가중 MSE 손실 + NMR 상한 최소화 손실 (미분 가능 STFT 경로 + detach된 PAM-2 문턱값) | eq:smrloss, eq:nmrloss |

**미분 가능/불가능 경계**: PAM-2 전역 마스킹 문턱값의 계산(마스커·톤성 선정,
불예측성, 확산, ATH 하한, 사전 반향)은 **미분 불가능**하며 `matlab/pam2_threshold.m`
(또는 동등한 NumPy 포팅)으로 **학습 이전에 오프라인**으로 한 번 계산합니다. 그
결과인 프레임별 문턱값 `gms`(dB)는 손실 함수 안에서 `.detach()`로 상수 처리되며,
STFT 로그-PSD 위에서 계산되는 손실은 복호 신호에 대해 **미분 가능**합니다.

### 실행 방법 (Python)

```sh
python3 python/torch_pam2_loss.py
```

`if __name__ == "__main__"` 스모크 테스트가 무작위 텐서로 두 손실을 호출하여 스칼라
손실 값을 출력하고, 값이 유한하며 음이 아님을 확인합니다. 실행에는 **PyTorch**가
필요합니다(`pip install torch`).

### 이 샌드박스에 대한 주의사항 (MATLAB/Octave 및 PyTorch)

이 문서를 작성한 샌드박스에는 **MATLAB/Octave가 설치되어 있지 않으며, PyTorch도
설치되어 있지 않고 네트워크가 차단(INTEGRATIONS_ONLY)되어 설치도 불가능**합니다.
따라서 `matlab/*.m` 스크립트와 `python/torch_pam2_loss.py`의 `__main__` 스모크
테스트는 **샌드박스 안에서 실행되지 않았습니다**. 다만 Python 파일은 `torch`를
import하지 않는 정적 검사인 `python3 -m py_compile python/torch_pam2_loss.py`로
문법 유효성을 확인했습니다. 실제 실행은 위 준비(Octave / PyTorch)를 갖춘 **외부
환경**에서 수행하십시오.

## 참고 문헌

- E. Zwicker and H. Fastl, *Psychoacoustics: Facts and Models*, Springer.
- T. Painter and A. Spanias, "Perceptual Coding of Digital Audio," *Proc. IEEE*, vol. 88, no. 4, 2000.
- ISO/IEC 11172-3 (MPEG-1 Audio).
- E. Terhardt, "Calculating virtual pitch," *Hearing Research*, 1979.
- M. Bosi and R. E. Goldberg, *Introduction to Digital Audio Coding and Standards*, Kluwer.
- K. Zhen, M. S. Lee, J. Sung, S. Beack, M. Kim, "Psychoacoustic Calibration of Loss Functions for Efficient End-to-End Neural Audio Coding," *IEEE Signal Processing Letters*, 2020. <https://saige.sice.indiana.edu/wp-content/uploads/spl2020_kzhen.pdf>
- F. A. P. Petitcolas, MPEG for MATLAB (reference MPEG audio implementation). <https://www.petitcolas.net/fabien/software/mpeg/>
- cocosci, *pam-nac* (Python PAM-1 masker + neural-codec losses). <https://github.com/cocosci/pam-nac>
