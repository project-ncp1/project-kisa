#!/bin/bash
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH
#KISA UNIX 취약점 자동 스캐너 v1.0(U-07계정관리)
#작성자 : Kimjoon-Yeong(정보 보안 엔지니어 준비생)

. function.sh 
LS_MAC=false
TARGET_FILE="$1"
if [[ $# -eq 0 ]];then
	echo "사용법:$0 <파일경로>"
	exit 1
fi

OS_TYPE=$(uname)
if [[ "$OS_TYPE" == "Darwin" ]]; then
	GROUP_OK="root|wheel"
	echo "macOS 모드: wheel 그룹 허용 중..."
else
	GROUP_OK="root"
	echo "Linux 모드: root 그룹만 허용"
fi

REPORT="project-kisa-$(date +%Y%m%d-%H%M%S).txt"
echo "===KISA U-07 계정관리 취약점 진단 시작===" > "$REPORT"
echo "대상 시스템: $(hostname) | $(date)" >> "$REPORT"

check_root_login() {
	echo "U-07-01: 루트 계정 확인 중..." | tee -a "$REPORT"

	if [[ "$OSTYPE"=="darwin*" ]]; then
		echo "PASS: macOS 루트 정상" | tee -a "$REPORT"
	else
		if [ -f /etc/shadow ]; then
			if grep "^root:" /etc/shadow 2>/dev/null | grep -q "!!"; then
				echo "PASS: 루트 비활성화" | tee -a "$REPORT"
			else
				echo "FAIL: 루트 활성화" | tee -a "$REPORT"
			fi
		else
			echo "주의!: /etc/shadow 파일 없음" | tee -a "$REPORT"
		fi
	fi
}

check_root_login
echo "======/etc/shadow의 root계정 활성화/비활성화 및 etc/shadow 파일 유무 진단 완료! $REPORT======" | tee -a "$REPORT"

#쉐도우 파일 점검
check_shadow_perm() {
	echo "U-08: /etc/shadow 소유자/권한 확인 중..." | tee -a "$REPORT"
	if [[ "$OSTYPE"=="darwin*" ]];then
		echo "PASS:macOS환경 (/etc/shadow 없음)" | tee -a "$REPORT"
		return
	fi

	if [ ! -f/etc/shadow ]; then
		echo "경고: /etc/shadow 파일없음" | tee -a "$REPORT"
		return
	fi

	OWNER=$(stat -c "%U" /etc/shadow)
	MODE=$(stat -c "%a" /etc/shadow)

	if [ "$OWNER" = "root" ] && [ "MODE" -le 400 ]; then
		echo "PASS:소유자 root, 권한 ${MODE} (400이하)" | tee -a "$REPORT"
	else
		echo "실패:소유자 ${OWNER}, 권한 ${MODE}" | tee -a "$REPORT"
		echo " 해결책:sudo chown root /etc/shadow && sudo chmod 400 /etc/shadow" | tee -a "$REPORT"
	fi
	}
check_shadow_perm
echo "====== /etc/shadow 소유자 및 권한 확인 완료! $REPORT ======" | tee -a "$REPORT"

# 호스트 점검
check_hosts_perm(){
	local FILE=${1:-"/etc/hosts"}
	echo "/etc/hosts 소유자/권한 확인 중...($FILE)"

	if [ ! -f"$FILE" ];then
		echo"파일없음:$FILE"
		return 1 ###1을 쓰는 이유 return 1은 실패했다 라는걸 알려줌
	fi

	local OWNER=$(ls -l "$FILE" | awk '{print$3}')
	local MODE=$(stat -c %a "$FILE" 2>/dev/null || stat -f %Lp "$FILE" 2>/dev/null | cut -c5 || echo "999")

	if [ "$OWNER" = "root" ] && [ "$MODE" -le 600 ] 2>/dev/null; then
		echo "PASS:소유자root, 권한 $MODE (600이하)"
	else
		echo "실패:소유자 $OWNER, 권한 $MODE -root/600 수정 필요"
	fi
	}

check_hosts_perm
echo "====== /etc/hosts 소유자/권한  진단 완료! $REPORT======" | tee -a "$REPORT"

#그룹 점검
check_group_perm(){ 
	FILE_GROUP=$(ls -l "$TARGET_FILE" | awk '{print $4}')

	if [[ "$GROUP_OK" == "root|wheel" ]]; then
		if [[ "$FILE_GROUP" == "root" || "$FILE_GROUP" == "wheel" ]];then
			echo "[PASS]그룹:$FILE_GROUP (macOS OK)"
		else
			echo "[FAIL]그룹:$FILE_GROUP (wheel/root만)"
		fi
	else
	if [[ "$FILE_GROUP" == "root" ]]; then
		echo "[PASS]그룹:$FILE_GROUP"
	else
		echo "[FAIL]그룹:$FILE_GROUP"
	fi
fi


}

check_group_perm
echo "============================U-10 진단 완료! $REPORT================================" | tee -a "$REPORT"



echo "============================U-15 진단 시작! $REPORT================================" | tee -a "$REPORT"
# World Writable 파일 점검
BAR
CODE "[U-15]World Writable 파일 점검"

cat << EOF >> "$REPORT"
[양호]:시스템 중요 파일에 world writable 파일이 존재하지 않거나, 존재 시 설정 이유를 확인하고 있는 경우
[취약]:시스템 중요 파일에 world writable 파일이 존재하나 해당 설정 이유를 확인하고 있지 않은 경우
EOF

BAR

WW_FILES=$(find / -xdev -type f -perm -002 2>/dev/null | grep -vE "/tmp/|proc/|/dev/|sys/" | head -20)

if [ -z "$WW_FILES" ]; then
	OK "시스템에 불필요한 world writable 파일이 없습니다."
else
	WARN "World writable 파일 존재(목록 확인 필요)"
	echo "취약 파일 목록:" | tee -a "$REPORT"
	echo "$WW_FILES" | while read file; do
		if [ -f "$file" ]; then
			PERM=$(stat -c %A "$file" 2>/dev/null || stat -f %A "$file" 2>/dev/null)
			OWNER=$(stat -c %U "$file" 2>/dev/null || stat -f %Su "$file" 2>/dev/null)
			echo "$file (권한: $PERM, 소유자: $OWNER)" | tee a- "$REPORT"
		fi
	done
fi

echo "=============================== U-15 진단 완료! $REPORT==================================" | tee -a "$REPORT"


echo "=============================== U-20 진단 시작! $REPORT==================================" | tee -a "$REPORT"

check_u_20_anon_ftp() {
	CODE "[U-20] Anonymous FTP 비활성화"

	echo "[U-20] Anonymous FTP 비활성화 점검 결과" >> "$REPORT"
#1. /etc/passwd에 ftp/annoymous 계정 체크
	FTP_USER=$(grep -i '^ftp\|^anonymous' /etc/passwd 2>dev/null)
	if [ -n "$FTP_USER" ]; then
		WARN "취약: /etc/passwd에 ftp/anonymous 계정 존재 -> userdel ftp/anonymous 필요" | tee -a "$REPORT"
		VULN_COUNT=1
	else
		OK "양호: ftp/anonymous 계정 없음" | tee -a "$REPORT"
	fi

#2. vsftpd.conf 체크 (anonymous_enable=NO 여부)
VSFTPD_CONF="/etc/vsftpd.conf /etc/vsftpd/vsftpd.conf"
VULN_VSFTPD=0
for conf in $VSFTPD_CONF; do
	if [ -f "$conf" ]; then
		ANON_SETTING=$(grep '^anonymous_enable' "$conf" 2>/dev/null | grep -i 'YES' || echo "NO")
		if echo "$ANON_SETTING" | grep -q 'YES'; then
			WARN "취약: $conf 에 anonymous_enable=YES -> NO로 변경 필요" | tee -a "$REPORT"
			VULN_VSFTPD=1
		else
			OK "양호: $conf anonymous_enable 비활성 또는 NO" | tee -a "$REPORT"
		fi
	fi
done

#3. proftpd.conf 체크 (Anonymous 섹션 존재 여부)
PROFTPD_CONF="/etc/proftpd.conf"
if [ -f "$PROFTPD_CONF" ]; then
	ANON_SECTION=$(grep -i '<Anonymous' "$PROFTPD_CONF" 2>/dev/null)
	if [ -n "$ANON_SECTION" ]; then
		WARN "취약: $PROFTPD_CONF에 <Anonymous> 섹션 존재 -> 주석 처리 필요" | tee -a "$REPORT"
	else
		OK "양호: $PROFTPD_CONF Anonymous 섹션 없음 또는 주석" | tee -a "$REPORT"
	fi
fi

#4. FTP 서비스 실행 여부 간단 체크 (ps로 ftp 프로세스)
FTP_RUNNING=$(ps aux 2>/dev/null | grep -E '(vsftpd|proftpd|ftpd)' | grep -v grep)
if [ -n "$FTP_RUNNING" ]; then
	INFO "FTP 서비스 실행 중: $FTP_RUNNING - 수동으로 anonymous 테스트 권장 (ftp localhost, anonymous 로그인
	시도)" | tee -a "$REPORT"
else
	OK "양호 : FTP 서비스 미실행" | tee -a "$REPORT"
fi

echo >> "$REPORT"

echo "======================================U-20 진단 끝!======================================="
}