_( This is a template for the weekly testing suite reports )_

@froura @agayayav @larriola @bdepaula @mandres @dmcclain @ialsina @dbeltran

Before starting...

- [ ] Update CHANGELOG with Highlights section and the month and year where the release is expected
- [ ] Check that the version of Autosubmit used in the config file of your testing suite is the latest. In case of doubt, ask the Autosubmit team.

### Testing Suite commit

( Which commit of the testing suite are you using? Check `git log` output )

### Steps to use the Testing Suite

* Use the tsuite1 shared account ( `sudo -i -u tsuite1` ).
* Configure the user mapping (<https://autosubmit.readthedocs.io/en/latest/userguide/user_mapping.html#how-to-activate-it-with-examples>).
* Make sure you have passwrd-less access to `lumi-cluster`, `mn5-cluster1`, etc.
* Add/Regenerate your API "Bearer" and GitLab tokens and add them in the tsuite `config.yml` file.

### General testing_suite workflow

* testing_suite --clean
* testing_suite --refresh clone
* testing_suite --create
* nohup testing_suite --run &

### testing_suite --status output & autosubmit version

( Output of the different job status plus their description )


* ex: #616
* ex: #617

/label ~"Testing suite"

()
