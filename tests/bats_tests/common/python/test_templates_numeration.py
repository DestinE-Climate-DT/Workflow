from pathlib import Path
from textwrap import dedent

import pytest
from pytest_mock import MockerFixture

from utils.templates_numeration import (
    check_variable_definition,
    fix_variable_definition,
)


@pytest.mark.parametrize(
    "text,error_expected",
    [
        (
            dedent("""\
        #/bin/bash
        set -eux

        # HEADER
        HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR%}
        EXPID=${3:-%DEFAULT.EXPID%}
        VARIABLE=${5:-%A.B.C.D.E%}
        # END_HEADER

        echo "Bye!"
        """),
            True,
        ),
        (
            dedent("""\
        #/bin/bash
        set -eux

        # HEADER
        HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR%}
        # Experiment ID
        EXPID=${2:-%DEFAULT.EXPID%}
        # END_HEADER

        echo "Bye!"
        """),
            False,
        ),
        (
            dedent("""\
        #/bin/bash

        # HEADER
        HPCROOTDIR=${1:-%HPCROOTDIR%}
        ROOTDIR=${2:-%ROOTDIR%}
        HPCUSER=${3:-%HPCUSER%}
        HPCHOST=${4:-%HPCHOST%}

        # Project name
        PROJDEST=${5:-%PROJECT.PROJECT_DESTINATION%}
        VARIABLE=${6:-%CAT1.CAT2.CAT3.CAT4%}
        # END_HEADER
        """),
            False,
        ),
    ],
    ids=[
        "invalid_template_numeration",
        "valid_template_numeration_1",
        "valid_template_numeration_2",
    ],
)
def test_check_works(
    tmp_path: Path, text: str, error_expected: bool, mocker: MockerFixture
) -> None:
    """Test that the template numeration script correctly checks scripts for errors."""

    script = tmp_path / "script.sh"
    with open(script, "w") as f:
        f.write(text)
        f.flush()

    if error_expected:
        with pytest.raises(ValueError):
            check_variable_definition(script)
    else:
        check_variable_definition(script)


def test_fix_works(tmp_path: Path) -> None:
    """Test that the template numeration script fixes scripts when errors are found."""

    before = dedent("""\
            #/bin/bash
            set -eux

            # HEADER
            HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR%}
            EXPID=${3:-%DEFAULT.EXPID%}
            # END_HEADER

            echo "Bye!"
            """)
    after = dedent("""\
            #/bin/bash
            set -eux

            # HEADER
            HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR%}
            EXPID=${2:-%DEFAULT.EXPID%}
            # END_HEADER

            echo "Bye!"
            """)

    script = tmp_path / "script.sh"
    with open(script, "w") as f:
        f.write(before)
        f.flush()

    fix_variable_definition(script)
    assert after == open(script).read()


def test_fix_works_extra_long(tmp_path: Path) -> None:
    """
    Test that the template numeration script fixes scripts when errors are found when there are more than 3 nested
    variables.
    """

    before = dedent("""\
            #/bin/bash
            set -eux

            # HEADER
            HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR.EXTRA.EXTRA2%}
            EXPID=${3:-%DEFAULT.EXPID%}
            # END_HEADER

            echo "Bye!"
            """)
    after = dedent("""\
            #/bin/bash
            set -eux

            # HEADER
            HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR.EXTRA.EXTRA2%}
            EXPID=${2:-%DEFAULT.EXPID%}
            # END_HEADER

            echo "Bye!"
            """)

    script = tmp_path / "script.sh"
    with open(script, "w") as f:
        f.write(before)
        f.flush()

    fix_variable_definition(script)
    assert after == open(script).read()

    before = dedent("""\
                #/bin/bash
                set -eux

                # HEADER
                HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR.EXTRA.EXTRA2.EXTRA3.EXTRA4%}
                EXPID=${4:-%DEFAULT.EXPID%}
                # END_HEADER

                echo "Bye!"
                """)
    after = dedent("""\
                #/bin/bash
                set -eux

                # HEADER
                HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR.EXTRA.EXTRA2.EXTRA3.EXTRA4%}
                EXPID=${2:-%DEFAULT.EXPID%}
                # END_HEADER

                echo "Bye!"
                """)

    script = tmp_path / "script.sh"
    with open(script, "w") as f:
        f.write(before)
        f.flush()

    fix_variable_definition(script)
    assert after == open(script).read()
