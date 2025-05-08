import logging


def config_logger(loglevel) -> None:
    """Configure the logger."""

    logging.basicConfig(
        level=getattr(
            logging, loglevel
        ),  # Set the logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",  # Log message format
        handlers=[
            logging.StreamHandler(),  # Log to the console
        ],
    )
