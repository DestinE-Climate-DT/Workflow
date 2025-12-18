_( This is a template for the weekly testing suite reports )_

@froura @agayayav @larriola @bdepaula @mandres @dmcclain @ialsina @dbeltran

Before starting...

- [ ] Block main and notify the team in the Slack channel de-mwt that you are starting the testing suite.
- [ ] Create the stashing branch.
- [ ] Update the CHANGELOG Highlights section and the month and year the release is expected.
- [ ] Check that the version of Autosubmit used in the config file of your testing suite is the latest. In case of doubt, ask the Autosubmit team.
- [ ] Add/Regenerate your API "Bearer" and LUMI-O tokens and add them in the tsuite config.yml file (instructions [here](https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/issues/1128)).
- [ ] After all tests pass, unblock main and change permissions to merge back to maintainers only (important!). If anyone merged new changes to the stashing branch, merge it to main **without** squashing the commits. If there are no changes, delete it.
- [ ] Run the clean command (testing_suite –config main_config.yml –clean)
- [ ] Announce in Slack that the testing suite has passed and main is now unblocked! :tada:
- [ ] Create the tag and press release.

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
