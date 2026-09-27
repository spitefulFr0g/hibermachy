"""Pure state machine for typed staged-sleep observation."""

from __future__ import annotations

import re

ATTEMPT_ID = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")
UNITS = {
    "suspend": "systemd-suspend.service",
    "suspend-then-hibernate": "systemd-suspend-then-hibernate.service",
}


class EvidenceState:
    def __init__(self, emit, now_ms, entry_window_ms, post_resume_window_ms=30000):
        self.emit = emit
        self.now_ms = now_ms
        self.entry_window_ms = entry_window_ms
        self.post_resume_window_ms = post_resume_window_ms
        self.attempt = None

    def _event(self, kind, **fields):
        self.emit({"schemaVersion": 1, "envelopeVersion": 1, "kind": kind, **fields})

    def submit(self, attempt_id, selected_mode):
        if self.attempt is not None:
            self._event("control-refused", reasonCode="HBR-SLEEP-BUSY")
            return False
        if not ATTEMPT_ID.fullmatch(str(attempt_id)) or selected_mode not in UNITS:
            self._event("control-refused", reasonCode="HBR-SLEEP-EVIDENCE-CONTROL-INVALID")
            return False
        now = self.now_ms()
        self.attempt = {
            "attemptId": attempt_id,
            "selectedMode": selected_mode,
            "unit": UNITS[selected_mode],
            "phase": "awaiting-entry",
            "entryDeadlineMs": now + self.entry_window_ms,
            "resumeDeadlineMs": None,
            "jobDone": False,
            "baselineJobId": None,
            "jobId": None,
        }
        return True

    def arm(self, baseline_job_id):
        if self.attempt is None:
            return False
        self.attempt["baselineJobId"] = int(baseline_job_id)
        self._event("attempt-armed", attemptId=self.attempt["attemptId"], selectedMode=self.attempt["selectedMode"],
                    unit=self.attempt["unit"], entryDeadlineMs=self.attempt["entryDeadlineMs"],
                    baselineJobId=self.attempt["baselineJobId"])
        return True

    def unit_job_started(self, unit, job_id, job_path):
        if self.attempt is None or unit != self.attempt["unit"]:
            return
        if self.attempt["baselineJobId"] is None or int(job_id) in (0, self.attempt["baselineJobId"]):
            return
        if self.attempt["jobId"] is not None and int(job_id) != self.attempt["jobId"]:
            self._evidence("unit-job-contradictory", "systemd", unit=unit, jobId=int(job_id))
            self._terminal("Indeterminate", "HBR-SLEEP-EVIDENCE-CONTRADICTORY", "contradictory-typed-evidence")
            return
        self.attempt["jobId"] = int(job_id)
        self._evidence("unit-job-started", "systemd", unit=unit, jobId=int(job_id), jobPath=str(job_path))

    def _evidence(self, evidence_type, source, **details):
        if self.attempt is None:
            return
        self._event("evidence", attemptId=self.attempt["attemptId"], selectedMode=self.attempt["selectedMode"],
                    evidenceType=evidence_type, source=source, monotonicTimeMs=self.now_ms(), details=details)

    def _terminal(self, outcome, reason_code, evidence_level):
        if self.attempt is None:
            return
        self._event("terminal", attemptId=self.attempt["attemptId"], selectedMode=self.attempt["selectedMode"],
                    outcome=outcome, reasonCode=reason_code, evidenceLevel=evidence_level,
                    details={"hibernationConfirmed": False})
        self.attempt = None

    def prepare_for_sleep(self, preparing):
        if self.attempt is None:
            return
        phase = self.attempt["phase"]
        if preparing:
            if phase != "awaiting-entry":
                self._evidence("sleep-transition-contradictory", "logind", preparing=True, phase=phase)
                self._terminal("Indeterminate", "HBR-SLEEP-EVIDENCE-CONTRADICTORY", "contradictory-typed-evidence")
                return
            self._evidence("sleep-entry", "logind", preparing=True)
            self.attempt["phase"] = "awaiting-resume"
            return
        if phase != "awaiting-resume":
            self._evidence("sleep-transition-contradictory", "logind", preparing=False, phase=phase)
            self._terminal("Indeterminate", "HBR-SLEEP-EVIDENCE-CONTRADICTORY", "contradictory-typed-evidence")
            return
        self._evidence("sleep-resume", "logind", preparing=False)
        self.attempt["phase"] = "awaiting-unit-result"
        self.attempt["resumeDeadlineMs"] = self.now_ms() + self.post_resume_window_ms
        if self.attempt["jobDone"]:
            self._terminal("Completed", "HBR-SLEEP-TRANSACTION-RETURNED", "typed-transaction-return")

    def job_removed(self, unit, result, job_id):
        if self.attempt is None or unit != self.attempt["unit"] or self.attempt["jobId"] != int(job_id):
            return
        self._evidence("unit-job-removed", "systemd", unit=unit, result=result, jobId=int(job_id))
        if result != "done":
            self._terminal("Failed", "HBR-SLEEP-UNIT-FAILED", "typed-unit-result")
            return
        self.attempt["jobDone"] = True
        if self.attempt["phase"] == "awaiting-unit-result":
            self._terminal("Completed", "HBR-SLEEP-TRANSACTION-RETURNED", "typed-transaction-return")

    def unit_properties(self, unit, interface, changed):
        if self.attempt is None or unit != self.attempt["unit"]:
            return
        result = changed.get("Result") if isinstance(changed, dict) else None
        active_state = changed.get("ActiveState") if isinstance(changed, dict) else None
        if result is not None or active_state is not None:
            self._evidence("unit-properties", "systemd", unit=unit, interface=interface,
                           result=result, activeState=active_state)
        if interface == "org.freedesktop.systemd1.Unit" and "Job" in changed:
            job_id, job_path = changed["Job"]
            self.unit_job_started(unit, job_id, job_path)
        if interface == "org.freedesktop.systemd1.Service" and result not in (None, "success"):
            self._terminal("Failed", "HBR-SLEEP-UNIT-FAILED", "typed-unit-result")

    def tick(self):
        if self.attempt is None:
            return
        now = self.now_ms()
        if self.attempt["phase"] == "awaiting-entry" and now >= self.attempt["entryDeadlineMs"]:
            self._terminal("Indeterminate", "HBR-SLEEP-EVIDENCE-MISSING", "missing-typed-evidence")
        elif self.attempt["phase"] == "awaiting-unit-result" and now >= self.attempt["resumeDeadlineMs"]:
            self._terminal("Indeterminate", "HBR-SLEEP-EVIDENCE-MISSING", "missing-typed-evidence")
