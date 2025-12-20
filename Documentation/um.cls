%% ****************************************************
%% ** **
%% ** University of Djillali Liabes         **
%% ** **
%% ** LaTeX Template for Thesis/Dissertation   **
%% ** **
%% ** Adapted from Prof. Jean-Paul Ebejer's Code   **
%% ** Updated for UDL Branding 2025        **
%% ** **
%% ****************************************************

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{um}[2025/12/20 v3.1 University of Djillali Liabes, Dissertation Template]

% Require LuaLaTeX
\RequirePackage{iftex}
\ifLuaTeX\else
\ClassError{um}{This class requires LuaLaTeX}{Run lualatex instead of pdflatex or xelatex.}
\fi

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{memoir}}
\ProcessOptions\relax
\LoadClass[11pt,a4paper,final]{memoir}


%% **************** Packages (Start) *********************

\RequirePackage{fontspec}
\defaultfontfeatures{Ligatures=TeX, Scale=MatchLowercase}
\setmainfont{TeX Gyre Pagella}
\setsansfont{Lato}
\setmonofont{Liberation Mono}

\RequirePackage[english]{babel} 
\RequirePackage[useregional]{datetime2}  
\RequirePackage{graphicx}   
\RequirePackage{xcolor}
\RequirePackage{eso-pic}
\RequirePackage{hyperref}
\RequirePackage[style=apa,backend=biber]{biblatex}
\RequirePackage{amsmath,amssymb}
\RequirePackage{floatpag}
\RequirePackage{longtable}
\RequirePackage{tabularx}   % REQUIRED for conditionsenv*
\RequirePackage{pdflscape}
\RequirePackage{amsthm}     
\RequirePackage{listings}
\RequirePackage[ruled]{algorithm2e}
\RequirePackage[printonlyused,withpage]{acronym}

% Fix for subfigure counter errors
\newsubfloat{figure} 

% Caption Setup
\captionnamefont{\small\bfseries}
\captiontitlefont{\small}
\captiondelim{: }
\setlength{\abovecaptionskip}{6pt}
\setlength{\belowcaptionskip}{6pt}
\captionwidth{0.95\textwidth}
\captionstyle{\centering} 

%% ****************** Packages (End) *********************


%% ************ UDL Branding Definitions *****************

\definecolor{UDLBlue}{rgb}{0.05, 0.14, 0.29}  % Deep Navy
\definecolor{UDLGold}{rgb}{0.78, 0.60, 0.09}  % Accent Gold
\colorlet{DissertationColor}{UDLBlue}   

% Logo with Padding
\def\logo{{\vspace{5mm}\includegraphics[width=35mm]{univ_logo_h}\vspace{5mm}}}

\def\degreeName#1{\gdef\@degreeName{#1}}
\def\supervisor#1{\gdef\@supervisor{#1}}
\def\cosupervisor#1{\gdef\@cosupervisor{#1}}
\def\department#1{\gdef\@department{#1}}
\def\faculty#1{\gdef\@faculty{#1}}
\def\subjectcode#1{\gdef\@subjectcode{#1}}
\def\tagline#1{\gdef\@tagline{#1}}
\def\doctype#1{\gdef\@doctype{#1}}
\def\authorID#1{\gdef\@authorID{#1}}
\def\submissionDate#1{\gdef\@submissionDate{#1}}

%% ************* Document Options ******************

\definecolor{codegreen}{rgb}{0,0.4,0}
\definecolor{codegray}{rgb}{0.5,0.5,0.5}
\definecolor{codepurple}{rgb}{0.58,0,0.82}
\definecolor{backcolour}{rgb}{0.97,0.98,1.0} 

\lstdefinestyle{mystyle}{
	backgroundcolor=\color{backcolour},   
	commentstyle=\color{codegreen},
	keywordstyle=\color{UDLBlue}\bfseries,
	numberstyle=\tiny\color{codegray},
	stringstyle=\color{codepurple},
	basicstyle=\ttfamily\footnotesize,
	breaklines=true,                 
	captionpos=b,                    
	keepspaces=true,                 
	numbers=left,                    
	numbersep=5pt,                  
	tabsize=2
}
\lstset{style=mystyle}

\OnehalfSpacing                                  
\setlength{\headsep}{1.5cm}                      
\nouppercaseheads								 

% Fix for \pagestyle{umpageback} undefined error
\makepagestyle{umpage}
\makeevenhead{umpage}{\color{gray}\sffamily\small\leftmark}{}{\color{gray}\sffamily\small\rightmark}
\makeoddhead{umpage}{\color{gray}\sffamily\small\leftmark}{}{\color{gray}\sffamily\small\rightmark}
\makeevenfoot{umpage}{}{\thepage}{}  			 
\makeoddfoot{umpage}{}{\thepage}{}
\makeheadrule{umpage}{\textwidth}{\normalrulethickness}

\copypagestyle{umpageback}{umpage}
\makeevenhead{umpageback}{\color{gray}\sffamily\small\leftmark}{}{}
\makeoddhead{umpageback}{}{}{\color{gray}\sffamily\small\rightmark}

\setlrmarginsandblock{3.7cm}{2.5cm}{*}           
\checkandfixthelayout                           

\graphicspath{{./images/}}                       
\DeclareGraphicsExtensions{.pdf,.jpeg,.png,.jpg} 
\chapterstyle{ell} 

% Typography
\renewcommand*{\chapnumfont}{\sffamily\HUGE\bfseries\color{UDLGold}} 
\renewcommand*{\chaptitlefont}{\sffamily\HUGE\bfseries\color{UDLBlue}}
\setsecheadstyle{\sffamily\LARGE\bfseries\color{UDLBlue}}
\setsubsecheadstyle{\sffamily\Large\color{UDLBlue}}
\setsubsubsecheadstyle{\sffamily\large\color{UDLBlue}}
\setsecnumformat{\csname the#1\endcsname\enskip{\color{UDLGold}\textbar}\enskip}
\renewcommand{\labelitemi}{\color{UDLGold}\scriptsize$\blacksquare$}

% Fix for \ra undefined error
\newcommand{\ra}[1]{\renewcommand{\arraystretch}{#1}} 

% Hyperlinks
\hypersetup{
	colorlinks=true,
	linkcolor=UDLBlue,
	citecolor=UDLBlue,
	urlcolor=UDLBlue,
	pdfborder={0 0 0},    
}

\setsecnumdepth{subsubsection}  
\settocdepth{subsection}

%% *************** Environments ******************

% Fix for conditionsenv* undefined error
\newenvironment{conditionsenv*}
{\par\vspace{\abovedisplayskip}\noindent
	\tabularx{\columnwidth}{>{$}l<{$} @{${}={}$} >{\raggedright\arraybackslash}X}}
{\endtabularx\par\vspace{\belowdisplayskip}}

% Title Page
\renewcommand{\maketitle}
{\begingroup
	\parbox[b][0.95\textheight][t]{0.25\textwidth}{
		\centering
		\vspace{1.5cm}
		\logo
	} 
	\hspace*{1ex}
	\textcolor{UDLGold}{\rule{2.5pt}{0.95\textheight}}
	\hspace*{4ex}
	\parbox[b][0.95\textheight][t]{0.70\textwidth}{
		\setlength{\parindent}{0pt}
		\sffamily
		\vspace{1.5cm}
		{\Huge\bfseries{\begin{Spacing}{1.15}\textcolor{UDLBlue}{\@title}\end{Spacing}}}
		\vspace*{2ex}
		\@ifundefined{@tagline}{\vspace*{3cm}}{{\large\textit{\@tagline}}\\[2cm]}    
		{\LARGE\bfseries \textsc{\@author}} \\[1cm]
		{\large Supervised by \@supervisor}
		\@ifundefined{@cosupervisor}{\\[2ex]}{\\[2ex]\large Co-supervised by \@cosupervisor}\\[1.5cm]
		{\large \@department} \\[1ex]
		{\large \@faculty} \\[1ex]
		{\large \textbf{University of Djillali Liabes}} \\
		\vfill
		{\bfseries \@submissionDate} \\[\baselineskip]
		\parbox[t]{0.90\linewidth}{\footnotesize\textit{A \@doctype\ submitted in partial fulfilment of the requirements for the degree of \@degreeName}.} 
	}
	\thispagestyle{empty}
	\if@openright\cleardoublepage\else\clearpage\fi
	\endgroup}

\addto{\captionsenglish}{\renewcommand{\abstractname}{\Large\bfseries\sffamily\textcolor{UDLBlue}{Abstract}}}

\newenvironment{acknowledgements}
{\renewcommand{\abstractname}{\Large\bfseries\sffamily\textcolor{UDLBlue}{Acknowledgements}}\abstract}
{\endabstract\if@openright\cleardoublepage\else\clearpage\fi}

\newenvironment{dedication}
{\clearpage           
	\thispagestyle{empty}
	\vspace*{\stretch{1}} 
	\itshape              
	\raggedleft          
	\textcolor{UDLBlue}
}
{\par 
	\vspace{\stretch{3}} 
	\if@openright\cleardoublepage\else\clearpage\fi
}        

\newenvironment{copyrightenv}
{\clearpage
	~\vfill
	\thispagestyle{empty}
	\begin{center}
		\noindent Copyright \textcopyright\the\year\ University of Djillali Liabes\\ 
		\noindent \textsc{www.univ-sba.dz}\\ 
		\noindent \textit{\today} 
	\end{center}
	\if@openright\cleardoublepage\else\clearpage\fi}

\newtheorem{theorem}{Theorem}[section]
\newtheorem{corollary}{Corollary}[theorem]
\newtheorem{lemma}[theorem]{Lemma}

\endinput