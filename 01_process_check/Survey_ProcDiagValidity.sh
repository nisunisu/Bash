#!/bin/bash

################################################################################
# Scriptname     : Survey_ProcDiagValidity.sh
# Character code : utf-8
# Arguments      : none
# Option         : none
# Usage          : ./Survey_ProcDiagValidity
# Return Code    :   0 # normal end
#                : 100 # warning end
#                : 255 # abnormal end
################################################################################

# VARIABLES :
readonly ARG_NUM=${#}
readonly ROOT="/tmp/survey_procdiagvalidity"
readonly DAT="${ROOT}/Survey_ProcDiagValidity.dat" # procname,minimum_count,max_count
readonly PSRESULT="${ROOT}/This_PsResult.tmp"
readonly IRREGULAR="${ROOT}/ProcDiag_IrregularCnt.out"
readonly NOTDEFINED="${ROOT}/ProcDiag_NotDefined.out"
readonly PROC_OWNER="myuser"                                    # どのユーザーのプロセスを調べるか
readonly ANTI_GREP_PATTERN="(ps aux)|(grep )|\-bash|sftp|sshd:" # ps結果のgrep -vE用
readonly SLEEP_TIME="5s"


# FUNCTIONS :
function fnTest_Path_Dat() {
  [ -f ${DAT} ] || { echo "Error : File does NOT exist.(${DAT})" ; exit 255 ; }
}

function fnValidate_CurrentTime() {
  local _now=$(date +"%H%M")
  [ ${_now} -ge "0730" -a ${_now} -le "2359" ] || { echo "Error : It's not VALID time. Please run this script at 07:30-23:59" ; exit 255 ; }
}

function fnGet_FromTime_ToTime() {
  # スクリプト実行時刻を算出
  readonly TIME_FROM=$( date -d"0 day 07:30:00" +"%s" ) # 今日のUNIXTIME
  readonly TIME_TILL=$( date -d"1 day 05:40:00" +"%s" ) # 明日のUNIXTIME
  
  echo "Info : Datetime determined."
}

function fnInitialize_OutFile() {
  echo "Datetime,ProcessCount,DefinedCnt_Min,DefinedCnt_Max,ProcessGrepPattern" > ${IRREGULAR}
  echo "Datetime,Process" > ${NOTDEFINED}
  
  echo "Info : Outfiles initialized."
}

function fnOut_PsResult() {
  # ps結果をリダイレクト
  ps aux | grep -E "^${PROC_OWNER}" | grep -vE "${ANTI_GREP_PATTERN}" | sort -k11 > ${PSRESULT}
}

function fnCompare_With_DiagDat() {
  # Arguments : $1 ... yyyymmddhhmmss型の日付
  # Return    : datの内容と合致する行を削除した${PSRESULT}
  
  # 引数チェック。引数が1個かつ整数14桁であること。
  local _now="${1}"
  [[ $# -eq 1 && "${_now}" =~ ^[0-9]{14}$ ]] || { echo "Error : Invalid Argument(${_now}). Go to next loop" ; return ; }
  
  # リダイレクト結果とdatを比較
  grep -vE "^$|^#" ${DAT} | while read LINE ; do
    local _prc=$( echo ${LINE} | cut -d"," -f1 ) # grepパターン
    local _min=$( echo ${LINE} | cut -d"," -f2 ) # 最小パターン合致件数
    local _max=$( echo ${LINE} | cut -d"," -f3 ) # 最大パターン合致件数
    
    # ps結果から行数をカウントし、定義している値の範囲外だった場合はIRREGULARにリダイレクトする
    local _grepCnt=$( grep "${_prc}" ${PSRESULT} | wc -l )
    [ ${_grepCnt} -ge ${_min} -a ${_grepCnt} -le ${_max} ] || echo "${_now},${_grepCnt},${_min},${_max},${_prc}" >> ${IRREGULAR}
    
    # このgrepパターンの行を削除
    sed -i -e "/${_prc}/d" ${PSRESULT} 
  done
}

function fnOut_NotDefinedProcs() {
  # Arguments : $1 ... yyyymmddhhmmss型の日付
  local _now="${1}"
  [[ $# -eq 1 && "${_now}" =~ ^[0-9]{14}$ ]] || { echo "Error : Invalid Argument(${_now}). Go to next loop" ; return ; }
  
  # sedの行削除を経て残った行をファイルに出力（csv形式））
  # 各行末に半角空白がセットされるけど気にしないこととする
  cat ${PSRESULT} |awk -v _ymdhms="${_now}" '{
    printf("%s,",_ymdhms)                     # 日付と時刻(末尾にカンマをセット)
    for(i=11; i<=NF; i++){ printf("%s ",$i) } # `ps aux`の11項目目以降を "文字列+半角空白" のセットで出力
    printf("\n")                              # 改行
  }' >> ${NOTDEFINED}
}

function fnSleep() {
  local _now=$(date +"%H:%M:%S")
  echo "Info : current time is '${_now}'. start sleep for ${SLEEP_TIME} ..."
  sleep ${SLEEP_TIME}
}

function fnNotify_Overtime() {
  echo "Info : It's before/after designated time. So stopping script..."
}

function fnStart() {
  echo "Info : Please run this script between 07:30 and 23:59."
  echo "Info : Otherwise, script STOPS immedeately."
  echo "Info : STARTING PROCESS..."
  echo "Info : -----------------------------------------------"
  echo "Info : Will execute ps command every ${SLEEP_TIME}."
  
  # 実行ユーザーチェック
  local _me=$(whoami)
  [ ${_me} = "root" -o ${_me} = ${PROC_OWNER} ] || { echo "Error : This script must run as root/${PROC_OWNER}." ; exit 255 ; }

  # 引数チェック
  [ ${ARG_NUM} -eq 0 ] || { echo "Error : No Argument is needes." ; exit 255 ; }
}

function fnEnd() {
  echo "Info : For irregular count of procnum, check ${IRREGULAR}"
  echo "Info : For undefined process name, check ${NOTDEFINED}"
  echo "Info : -----------------------------------------------"
  echo "Info : PROCESS NORMAL END."
}

function fnMain() {
  fnStart
  fnTest_Path_Dat
  fnValidate_CurrentTime
  fnGet_FromTime_ToTime
  fnInitialize_OutFile
  while : ; do
    local _now=$( date )
    local _ymdNow=$( date -d"${_now}" +"%Y%m%d%H%M%S" )
    local _unxNow=$( date -d"${_now}" +"%s" )
    if [ ${_unxNow} -ge ${TIME_FROM} -a ${_unxNow} -le ${TIME_TILL} ] ; then
      fnOut_PsResult
      fnCompare_With_DiagDat "${_ymdNow}"
      fnOut_NotDefinedProcs "${_ymdNow}"
      fnSleep
    else
      fnNotify_Overtime
      break
    fi
  done
  fnEnd
}


# MAIN :
fnMain
