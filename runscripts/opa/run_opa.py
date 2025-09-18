import argparse
from pathlib import Path
from functools import partial
import warnings


from gsv import GSVRetriever

from one_pass.opa import Opa

try:
    from runscripts.utils import add_app_experiment_arguments, AppExperiment
except ImportError:
    # Fallback: running as a script, not as an installed package
    import sys

    # Add the parent of 'dn' (i.e., 'runscripts') to sys.path
    sys.path.append(str(Path(__file__).parent.parent.resolve()))
    from utils import add_app_experiment_arguments, AppExperiment


def _get_parser():
    parser = argparse.ArgumentParser(description="Runscript for OPA job.")
    parser.add_argument(
        "--request_dir",
        type=str,
        required=True,
        help="Directory where requests are stored",
    )
    parser.add_argument(
        "--read_from_databridge",
        required=True,
        help="Read from databridge",
        default=False,
    )
    parser.add_argument(
        "--request_number",
        type=int,
        required=True,
        help="Request number",
    )
    parser.add_argument(
        "--outpath",
        type=str,
        required=Path,
        help="Output path for OPA",
    )
    add_app_experiment_arguments(parser)
    return parser


OpaAppExperiment = partial(AppExperiment, _request_suffix="_OPA*")


def check_deprecation(oparequest):
    """Check deprecated keys in gsv request since One_Pass v0.7.0,
    i.e. integration with Bias Adjustment.
    """

    if "bias_adjustment" in oparequest:
        warnings.warn(
            "OPA request key 'bias_adjustment' was deprecated in One_Pass v0.7.0. "
            "Please, use the key 'bias_adjust' instead.",
            DeprecationWarning,
        )
        oparequest["bias_adjust"] = oparequest.pop("bias_adjustment")

    if "bias_adjustment_method" in oparequest:
        warnings.warn(
            "OPA request key 'bias_adjustment_method' was deprecated in One_Pass v0.7.0. "
            "Please, use the key 'ba_future_method' instead.",
            DeprecationWarning,
        )
        oparequest["ba_future_method"] = oparequest.pop("bias_adjustment_method")

    if oparequest.get("stat") == "bias_correction":
        raise RuntimeError(
            "Opa request key-value combination {'stat': 'bias_correction'} is deprecated. "
            "Please, use a valid stat key together with {'bias_adjust': True}. "
            "(Introduced in One_Pass v0.7.0)"
        )


def main():
    """Run OPA."""

    args = _get_parser().parse_args()

    request_dir = args.request_dir
    read_from_databridge = args.read_from_databridge
    request_number = args.request_number
    outpath = args.outpath
    chunk = args.chunk
    split = args.split
    app_names = args.app_names
    expid = args.expid
    member = args.member
    realization = args.realization
    datelist = args.datelist

    print("--request_dir: ", request_dir)
    print("--read_from_databridge: ", read_from_databridge)
    print("--request_number: ", request_number)
    print("--outpath", outpath)
    print("--chunk: ", chunk)
    print("--split: ", split)
    print("--expid", expid)
    print("--app_names", app_names)
    # Use either member or realization, not both
    print("--member", member)
    print("--realization", realization)
    print("--datelist", datelist)

    app_experiment = OpaAppExperiment(
        chunk=chunk,
        split=split,
        expid=expid,
        member=member,
        realization=realization,
        app_names=app_names,
        datelist=datelist,
    )

    gsvrequests, oparequests = app_experiment.get_requests(request_dir)

    request_number_range = (1, len(gsvrequests) + 1)

    if (
        request_number < request_number_range[0]
        or request_number > request_number_range[1]
    ):
        raise ValueError(
            f"Request number ({request_number}) is out of allowed range: "
            f"({request_number_range[0]}, {request_number_range[1]})."
        )
    gsvrequest = gsvrequests[request_number - 1]
    oparequest = oparequests[request_number - 1]

    # Update OPA request with outpath for save and checkpoint functionalities
    oparequest.update(
        {
            "save": True,
            "checkpoint": True,
            "save_filepath": outpath,
            "checkpoint_filepath": outpath,
        }
    )

    # Check whether deprecated variables are used from old One_Pass version
    # (Prior to v0.7.0)
    check_deprecation(oparequest)

    # Get data from gsv
    gsv = GSVRetriever()
    data = gsv.request_data(gsvrequest, use_stream_iterator=read_from_databridge)

    # Run One Pass algorithm on a specific stat & variable controlled by the oparequest
    opa_stat = Opa(oparequest)
    opa_stat.compute(data)


if __name__ == "__main__":
    main()
