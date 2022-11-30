#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} [Cソースファイル]
	Options : -r

	Cソースファイルの凝集度（LCOM3）を計算する。
	-rオプションにより関数・変数の定義と、関数から変数へのアクセスの一覧を出力する。
	 F：関数の定義
	 V：変数の定義
	 C：関数から変数へのアクセス
	USAGE
  exit 1
}

######################################################################
# コマンドチェック
######################################################################

# GNU cflowを利用するので存在をチェック
if type cflow >/dev/null 2>&1           &&
   cflow --version | grep -q 'GNU cflow';  then
  :
else
  echo "${0##*/}: GNU cflow not found" 1>&2
  exit 2
fi

# Universal Ctagsを利用するので存在をチェック
if type ctags >/dev/null 2>&1                 &&
   ctags --version | grep -q 'Universal Ctags';  then
  :
else
  echo "${0##*/}: Universal Ctags not found" 1>&2
  exit 3  
fi

######################################################################
# パラメータ
######################################################################

# 初期設定
opr=''
opt_r='no'

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -r)                  opt_r='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "$opr" ] ; then
        opr=${arg}
      else
        echo "${0##*/}: invalid args" 1>&2
        exit 11
      fi
      ;;
  esac

  i=$((i + 1))
done

# 読み取り可能な通常ファイルであるか判定
if   [ -z "$opr" ]; then
  echo "${0##*/}: source file must be specified" 1>&2
  exit 21
elif [ ! -f "$opr" ] || [ ! -r "$opr" ]; then
  echo "${0##*/}: \"$opr\" cannot be opened" 1>&2
  exit 22
else
  :
fi

# パラメータを決定
csrc=$opr
isrel=$opt_r

######################################################################
# 前準備
######################################################################

# 変数定義を保存する一時ファイルのパスを生成
tmpval="${TMPDIR:-/tmp}/${0##*/}.tmp.value.$$"
# 一時ファイルの後始末の動作を設定
trap "[ -e $tmpval ] && rm $tmpval" EXIT HUP INT QUIT ALRM SEGV TERM

######################################################################
# 本体処理
######################################################################

# ファイルのクロスリファレンスを取得
ctags -x "$csrc"                                                     |
# 変数のみ抽出
awk '$2 == "variable" { print $1; }'                                 |
# ソート
sort                                                                 |
# 一時ファイルに保存
cat > "$tmpval"

# 変数の参照を含むすべての呼び出し関係を出力
cflow -A -ix "$csrc"                                                 |

# シグネチャが明確な関数と変数（内部で定義されているもの）を抽出
sed -n '/<[^>]*>:\{0,1\}$/p'                                         |

# 定義情報を削除
sed 's! <[^>]*>:\{0,1\}$!!'                                          |
# 余分な装飾を削除
sed 's!()$!!'                                                        |

# 呼び出しの深さを計算
awk '{ match($0, /[^ ]/); print RSTART " " $1 }'                     |
awk '{ print ($1-1)/4, $2; }'                                        |
# 呼び出し関係を行形式に変更
awk '
BEGIN {
  fnc[-1] = "top";
}
{ 
  depth = $1; fnc[$1] = $2;
  print fnc[depth-1], fnc[depth];
}
'                                                                    |

# 重複を除去（callee → caller の順にソート）
sort -b -k2,2 -k1,1                                                  |
uniq                                                                 |

# 変数の呼び出しのみを抽出（変数名で結合）
join -1 2 -2 1 -o 1.1,1.2 - "$tmpval"                                |

# 呼び出し関係を成形
awk '{ print "C", $1, $2 }'                                          |

{
  # クロスリファレンスを出力
  ctags -x "$csrc"                                                   |
  # 変数と関数の定義のみを抽出
  awk '
  $2 == "variable" { print "V", $1; }
  $2 == "function" { print "F", $1; }
  '

  # 呼び出し関係を連結
  cat
}                                                                    |

if [ "$isrel" = "no" ]; then
  # 凝集度を出力
  awk -v isrel=$isrel '
  $1 == "F" { cnt_function++; }
  $1 == "V" { cnt_value++;    }
  $1 == "C" { cnt_call++;     }

  END {
    mol = cnt_call/cnt_value - cnt_function;
    den = 1 - cnt_function;

    print "'"$csrc"'", mol / den;
  }
  '
else
  # 関数・変数の定義と、関数から変数へのアクセスの一覧を出力
  cat
fi
