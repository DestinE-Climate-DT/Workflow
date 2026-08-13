from __future__ import annotations


from wftools.util import extract_error_summary, strip_ansi


class TestStripAnsi:
    """Tests for strip_ansi utility function."""

    def test_strip_ansi_with_codes(self):
        text = "\x1b[31mERROR\x1b[0m: something failed \x1b[1;33mwarning\x1b[0m"
        result = strip_ansi(text)
        assert result == "ERROR: something failed warning"

    def test_strip_ansi_empty(self):
        assert strip_ansi("") == ""

    def test_strip_ansi_no_codes(self):
        plain = "Just a normal line of text, nothing special."
        assert strip_ansi(plain) == plain

    def test_strip_ansi_cursor_codes(self):
        text = "\x1b[2Kprogress: 100%\x1b[1G"
        result = strip_ansi(text)
        assert "progress: 100%" in result
        assert "\x1b" not in result

    def test_strip_ansi_multiline(self):
        text = "\x1b[32mOK\x1b[0m\n\x1b[31mFAIL\x1b[0m\n\x1b[33mSKIP\x1b[0m"
        result = strip_ansi(text)
        assert result == "OK\nFAIL\nSKIP"


class TestExtractErrorSummary:
    """Tests for extract_error_summary utility function."""

    def test_extract_error_summary_python_traceback(self):
        err = (
            "+ set -xuve\n"
            "+ python3 run.py\n"
            "Traceback (most recent call last):\n"
            '  File "run.py", line 42, in <module>\n'
            "    do_stuff()\n"
            "ValueError: invalid literal for int() with base 10: 'abc'\n"
        )
        result = extract_error_summary(err)
        assert "ValueError" in result
        assert "invalid literal" in result

    def test_extract_error_summary_slurm_error(self):
        err = (
            "+ module load cray-python\n"
            "+ srun --ntasks=4 ./sim.exe\n"
            "slurmstepd: error: oom-kill event in step 12345.0\n"
            "srun: error: node42: task 0: Out of Memory\n"
        )
        result = extract_error_summary(err)
        # Should match the last SLURM-related line
        assert "srun" in result or "slurm" in result.lower()

    def test_extract_error_summary_grib_error(self):
        err = (
            "+ grib_set -s edition=2 input.grib output.grib\n"
            "grib_set: unable to set edition: Key/value not found\n"
        )
        result = extract_error_summary(err)
        assert "grib_set" in result
        assert "Key/value not found" in result

    def test_extract_error_summary_fatal_indicator(self):
        err = (
            "+ ./model.exe\n"
            "Model initialization complete\n"
            "Segmentation fault (core dumped)\n"
        )
        result = extract_error_summary(err)
        assert "Segmentation fault" in result

    def test_extract_error_summary_exit_code(self):
        err = "+ set -xuve\n+ ./run.sh\nexit 137\n"
        result = extract_error_summary(err)
        assert "exit 137" in result

    def test_extract_error_summary_trace_only(self):
        err = "+ set -xuve\n+ cd /work/exp\n+ ls -la\n+ echo done\n"
        result = extract_error_summary(err)
        # All lines start with +, so fallback to default message
        assert result == "Job failed \u2014 see full log for details"

    def test_extract_error_summary_empty(self):
        assert extract_error_summary("") == "Job failed \u2014 see full log for details"
        assert (
            extract_error_summary("   ") == "Job failed \u2014 see full log for details"
        )
        assert (
            extract_error_summary(None) == "Job failed \u2014 see full log for details"
        )

    def test_extract_error_summary_truncation(self):
        # Build a line that exceeds 200 characters and matches a known pattern
        long_msg = "ValueError: " + "x" * 250
        err = f"+ setup\n{long_msg}\n"
        result = extract_error_summary(err)
        assert len(result) <= 200
        assert result.startswith("ValueError:")

    def test_extract_error_summary_last_match_wins(self):
        err = "ValueError: first error\n+ trace line\nRuntimeError: second error\n"
        result = extract_error_summary(err)
        # Last matching line should be returned
        assert "RuntimeError" in result
        assert "second error" in result

    def test_extract_error_summary_fallback_to_last_non_trace(self):
        err = "+ trace1\n+ trace2\nsome non-trace output line\n+ trace3\n"
        result = extract_error_summary(err)
        assert result == "some non-trace output line"

    def test_extract_error_summary_out_of_memory_case_insensitive(self):
        err = "Allocating buffers...\nOUT OF MEMORY during allocation\n"
        result = extract_error_summary(err)
        assert "OUT OF MEMORY" in result

    def test_extract_error_summary_killed(self):
        err = "Running simulation step 42\nKilled\n"
        result = extract_error_summary(err)
        assert "Killed" in result

    def test_extract_error_summary_fatal_in_trace_line_ignored(self):
        # Lines starting with + should not match the fatal pattern
        err = "+ echo FATAL error test\nnormal output\n"
        result = extract_error_summary(err)
        # The + line should not be picked up as a fatal indicator;
        # fallback to last non-trace line
        assert result == "normal output"
