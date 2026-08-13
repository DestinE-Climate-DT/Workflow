"""HPC resource-accounting for the tsuite CI.

What a CI experiment cost -- node-hours, core-hours, energy -- across every job
it ran, from sacct where the scheduler saw it and from Autosubmit's own record
where it did not.  Surfaced as a JSON artifact plus a GitLab metrics file.
"""
