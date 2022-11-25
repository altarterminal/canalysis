#!/bin/sh
set -eu

######################################################################
# 設定
######################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} [Cソースファイル]
	Options : -o<出力画像ファイル名>

	Cソースファイル内の呼び出し関係を画像出力する。

	-oオプションで出力画像の名前を指定できる。
	デフォルトは「Cソースファイル名.png」。
	USAGE
  exit 1
}

# dot言語ヘッダ出力
print_graphheader () {
  cat <<-'EOF'
	digraph graph_name {
	  graph [
	    charset = "UTF-8";
	    layout  = dot;
	  ];
	EOF
}

# dot言語フッタ出力
print_graphfooter () {
  cat <<-'EOF'
	}
	EOF
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

# Graphvizを利用するので存在をチェック
if type dot >/dev/null 2>&1; then
  :
else
  echo "${0##*/}: Graphviz not found" 1>&2
  exit 3
fi

######################################################################
# パラメータ
######################################################################

# 変数を初期化
opr=''
opt_o=''

# 引数をパース
i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;    
    -o*)                 opt_o=${arg#-o}      ;;
    *)
      if [ $i -eq $# ] && [ -z "$opr" ] ; then
        opr=$arg
      else
        echo "${0##*/}: invalid args" 1>&2
        exit 11
      fi
      ;;
  esac

  i=$((i + 1))
done

# 読み取り可能な通常ファイルであるか判定
if   [ "_$opr" = '_' ]; then
  echo "${0##*/}: c source must be specified" 1>&2
  exit 21  
elif [ ! -f "$opr"   ] || [ ! -r "$opr"    ]; then
  echo "${0##*/}: \"$opr\" cannot be opened" 1>&2
  exit 22
else
  :
fi

# パラメータを決定
csrc=$opr

if [ "_$opt_o" = '_' ]; then
  cimg="${csrc}.png"
else
  cimg="$opt_o"
fi

######################################################################
# 本体処理
######################################################################

# mainから到達不可能なものも含む呼び出し関係を出力
cflow -A "$csrc"                                                     |

# 不要な情報を削除
sed 's/ <[^>]*>//'                                                   |
sed 's/:$//'                                                         |
sed 's/()$//'                                                        |

# 呼び出しの深さのインデントを数値に変換
awk '{ match($0, /[^ ]/); print RSTART " " $0 }'                     |
awk '{ $1 = ($1 - 1)/4; print $0 }'                                  |

# 関数の呼び出しを行形式に変換
awk '
BEGIN {
  fnc[-1] = "top"
}
{ 
  depth = $1; fnc[$1] = $2;
  print fnc[depth-1], fnc[depth];
} 
'                                                                    |

# 重複を削除
sort                                                                 |
uniq                                                                 |

# dot言語のための成形
awk '{ print $1, "->", $2; }'                                        |
sed 's/$/;/'                                                         |
{ print_graphheader; cat; print_graphfooter; }                       |

# コールグラフを生成
dot -Tpng > "$cimg"
