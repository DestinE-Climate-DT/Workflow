def convert_dict_to_flags(d: dict):
    flags = []
    for key, value in d.items():
        flags.append(f'--{key.lower()} "{value}"')
    return " ".join(flags)


__all__ = ["convert_dict_to_flags"]
