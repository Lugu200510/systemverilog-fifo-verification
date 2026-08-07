#!/bin/bash

set -o pipefail

TOP="fifo_tb"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RTL_FILE="$PROJECT_DIR/rtl/fifo.sv"
TB_FILE="$PROJECT_DIR/tb/fifo_tb.sv"

cd "$SCRIPT_DIR" || exit 1

FILELIST="filelist.f"

SIMV="./simv"
COMPILE_LOG="compile.log"
SIM_LOG="simulation.log"

COV_DIR="simv.vdb"
URG_DIR="urgReport"

OPEN_WAVE="${OPEN_WAVE:-1}"
OPEN_COVERAGE="${OPEN_COVERAGE:-1}"
OPEN_HTML="${OPEN_HTML:-0}"

COV_METRICS="line+cond+branch+tgl"

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
RESET="\033[0m"

info()
{
    echo -e "${BLUE}[INFO]${RESET} $1"
}

success()
{
    echo -e "${GREEN}[PASS]${RESET} $1"
}

warning()
{
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

error()
{
    echo -e "${RED}[ERROR]${RESET} $1"
}

info "Checking simulation tools..."

if ! command -v vcs >/dev/null 2>&1; then
    error "VCS was not found. Please configure the Synopsys VCS environment first."
    exit 1
fi

if command -v urg >/dev/null 2>&1; then
    HAS_URG=1
    success "URG found"
else
    HAS_URG=0
    warning "URG was not found. Coverage HTML report generation will be skipped."
fi

if command -v verdi >/dev/null 2>&1; then
    HAS_VERDI=1
    success "Verdi found"
else
    HAS_VERDI=0
    warning "Verdi was not found. Verdi launch steps will be skipped."
fi

success "VCS environment check completed"

info "Checking source files..."

if [ ! -f "$RTL_FILE" ]; then
    error "RTL file not found: $RTL_FILE"
    exit 1
fi

if [ ! -f "$TB_FILE" ]; then
    error "Testbench file not found: $TB_FILE"
    exit 1
fi

success "Source file check completed"

info "Cleaning old compile, simulation, and coverage files..."

rm -rf \
    simv \
    simv.daidir \
    simv.vdb \
    csrc \
    DVEfiles \
    urgReport \
    verdiLog \
    novas.conf \
    novas.rc \
    novas.fsdb \
    *.fsdb \
    *.vpd \
    *.vcd \
    *.key \
    *.log \
    *.daidir \
    ucli.key \
    vc_hdrs.h \
    inter.vpd \
    AN.DB \
    .vcs.timestamp \
    "$FILELIST"

success "Cleanup completed"

info "Generating $FILELIST ..."

cat > "$FILELIST" <<EOF
$RTL_FILE
$TB_FILE
EOF

success "$FILELIST generated"

echo "---------------- filelist.f ----------------"
cat "$FILELIST"
echo "------------------------------------------------"

info "Starting VCS compilation..."

vcs \
    -full64 \
    -sverilog \
    -timescale=1ns/1ps \
    -top "$TOP" \
    -f "$FILELIST" \
    -debug_access+all \
    -kdb \
    -lca \
    -cm "$COV_METRICS" \
    -cm_dir "$COV_DIR" \
    -cm_name fifo_coverage \
    -l "$COMPILE_LOG"

VCS_STATUS=$?

if [ $VCS_STATUS -ne 0 ]; then
    error "VCS compilation failed. Check: $COMPILE_LOG"
    exit $VCS_STATUS
fi

if [ ! -x "$SIMV" ]; then
    error "Compilation completed, but simv was not generated."
    exit 1
fi

success "VCS compilation succeeded"

info "Starting FIFO simulation..."

"$SIMV" \
    -cm "$COV_METRICS" \
    -cm_dir "$COV_DIR" \
    -cm_name fifo_coverage \
    +vcs+vcdpluson \
    +vcs+vcdplusmemon \
    -l "$SIM_LOG"

SIM_STATUS=$?

if [ $SIM_STATUS -ne 0 ]; then
    error "Simulation failed. Check: $SIM_LOG"
    exit $SIM_STATUS
fi

success "Simulation completed"

info "Checking testbench results..."

if grep -Eiq "FAIL|ERROR|FATAL" "$SIM_LOG"; then
    warning "FAIL / ERROR / FATAL found in simulation.log. Please inspect the test results."
else
    success "No obvious FAIL / ERROR / FATAL found in simulation.log"
fi

echo
echo "================ Simulation Summary ================"

grep -Ei \
    "PASS|FAIL|PASSED|FAILED|coverage|TEST" \
    "$SIM_LOG" | tail -n 40 || true

echo "================================================"
echo

if [ "$HAS_URG" -eq 1 ] && [ -d "$COV_DIR" ]; then

    info "Generating URG coverage report..."

    urg \
        -full64 \
        -dir "$COV_DIR" \
        -report "$URG_DIR" \
        -format both \
        -show tests \
        -grade \
        -metric "$COV_METRICS"

    URG_STATUS=$?

    if [ $URG_STATUS -eq 0 ]; then
        success "Coverage report generated: $URG_DIR"

        echo
        echo "================ Coverage Summary ================"

        if [ -f "$URG_DIR/dashboard.txt" ]; then
            cat "$URG_DIR/dashboard.txt"
        elif [ -f "$URG_DIR/grading.txt" ]; then
            cat "$URG_DIR/grading.txt"
        else
            find "$URG_DIR" -maxdepth 2 -type f \
                \( -name "*.txt" -o -name "*.log" \) \
                -print | head
        fi

        echo "=================================================="
        echo

    else
        warning "URG coverage report generation failed."
    fi

else
    warning "URG report was not generated."
fi

if [ "$OPEN_WAVE" = "1" ]; then

    if [ "$HAS_VERDI" -eq 1 ]; then
        info "Opening Verdi..."

        WAVE_FILE=""

        if ls *.fsdb >/dev/null 2>&1; then
            WAVE_FILE=$(ls -1 *.fsdb | head -n 1)
        elif ls *.vpd >/dev/null 2>&1; then
            WAVE_FILE=$(ls -1 *.vpd | head -n 1)
        elif ls *.vcd >/dev/null 2>&1; then
            WAVE_FILE=$(ls -1 *.vcd | head -n 1)
        fi

        if [ -n "$WAVE_FILE" ]; then
            success "Waveform file found: $WAVE_FILE"
            verdi \
                -sv \
                -f "$FILELIST" \
                -top "$TOP" \
                -ssf "$WAVE_FILE" &
        else
            warning "No FSDB, VPD, or VCD waveform file was found."
            verdi \
                -sv \
                -f "$FILELIST" \
                -top "$TOP" &
        fi

    else
        warning "OPEN_WAVE=1, but Verdi was not found."
    fi
fi

if [ "$OPEN_COVERAGE" = "1" ]; then

    if [ "$HAS_VERDI" -eq 1 ] && [ -d "$COV_DIR" ]; then

        info "Opening the coverage database in Verdi..."

        verdi \
            -cov \
            -covdir "$COV_DIR" \
            -sv \
            -f "$FILELIST" \
            -top "$TOP" &

    else
        warning "Unable to open Verdi Coverage."
    fi
fi

if [ "$OPEN_HTML" = "1" ]; then

    HTML_FILE="$URG_DIR/dashboard.html"

    if [ ! -f "$HTML_FILE" ]; then
        HTML_FILE="$URG_DIR/index.html"
    fi

    if [ -f "$HTML_FILE" ]; then

        info "Opening the coverage HTML report..."

        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$HTML_FILE" >/dev/null 2>&1 &
        else
            warning "xdg-open was not found. Open manually: $HTML_FILE"
        fi

    else
        warning "Coverage HTML file was not found."
    fi
fi

echo
echo "============================================================"
echo -e "${GREEN}FIFO simulation flow completed${RESET}"
echo "============================================================"
echo "TOP              : $TOP"
echo "RTL              : $RTL_FILE"
echo "Testbench        : $TB_FILE"
echo "Compile Log      : $COMPILE_LOG"
echo "Simulation Log   : $SIM_LOG"
echo "Coverage DB      : $COV_DIR"
echo "URG Report       : $URG_DIR"
echo "Coverage Metrics : $COV_METRICS"
echo "============================================================"
echo
echo "Verdi waveform and coverage windows are opened automatically."
echo "Optional:"
echo "  OPEN_WAVE=0 ./run.sh"
echo "  OPEN_COVERAGE=0 ./run.sh"
echo "  OPEN_HTML=1 ./run.sh"
echo
