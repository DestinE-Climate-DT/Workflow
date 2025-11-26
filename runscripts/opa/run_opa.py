import argparse
import warnings

import yaml

from gsv import GSVRetriever

from one_pass.opa import Opa


def _get_parser():
    parser = argparse.ArgumentParser(description="Runscript for OPA job.")
    parser.add_argument(
        "--request", required=True, help="Input file one pass", default=1
    )
    parser.add_argument(
        "--read_from_databridge",
        required=True,
        help="Read from databridge",
        default=False,
    )
    return parser


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

    print("--request: ", args.request)
    print("--read_from_databridge: ", args.read_from_databridge)

    request_file = f"{args.request}"
    read_from_databridge = args.read_from_databridge

    # Read opa and gsv requests
    with open(request_file, "r", encoding="utf-8") as rf:
        request = yaml.safe_load(rf)
        oparequest = request["OPAREQUEST"]
        gsvrequest = request["GSVREQUEST"]

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
