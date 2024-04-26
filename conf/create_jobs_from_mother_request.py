# This creates the jobs.yml from the mother request coming from all the epplciations.
import yaml
import copy

def check_elements_in_list(app_requested, app_available):
    if not app_requested:
        raise ValueError("You should at least request one application. Check your <expid>/main.yml")

    if all(element in app_available for element in app_requested):
        return True
    else:
        missing_elements = [element for element in app_requested if element not in app_available]
        raise ValueError(f"Not all requested applications {app_requested} are currently able to run. Check the current ones in {app_available}. Missing apps: {missing_elements}")

def write_files(jobs, main_yml):
    """
    Gets the jobs dictionary and creates the jobslists given the details in main.yml.
    """
    if main_yml['RUN']['WORKFLOW'] == "end-to-end":
        # Output a new jobs file
        out_filename = "jobs_end-to-end.yml"
        with open(out_filename, 'w') as outfile:
            yaml.safe_dump(jobs, outfile, default_flow_style=False)

        with open('jobs_end-to-end.yml', 'r') as file:
            content = file.read()
            final_content=content.replace("\"'", "\"")
            final_content=final_content.replace("'\"", "\"")

        # Writing the modified content back to the file
        with open(out_filename, 'w') as file:
            file.write(final_content)
            print(content) #get in terminal the output
        print("jobs_end-to-end.yml has been created.")

    elif main_yml['RUN']['WORKFLOW'] == "apps":
        # write apps jobs file (no ini, no sim):
        jobs_apps=copy.deepcopy(jobs)
        jobs_apps['JOBS']['DN']['DEPENDENCIES']={'REMOTE_SETUP': {'STATUS': 'COMPLETED'}, 'DN': {'SPLITS_FROM': {'all': {'SPLITS_TO': 'previous'}}}}
        del jobs_apps['JOBS']['SIM']
        del jobs_apps['JOBS']['INI']
        #del jobs_apps['JOBS']['DQC']

        out_filename = "jobs_apps.yml"
        with open(out_filename, 'w') as outfile:
            yaml.safe_dump(jobs_apps, outfile, default_flow_style=False)

        with open('jobs_apps.yml', 'r') as file:
            content = file.read()
            final_content=content.replace("\"'", "\"")
            final_content=final_content.replace("'\"", "\"")

        with open('jobs_apps.yml', 'w') as file:
            file.write(final_content)
            print(final_content)
        print("jobs_apps.yml has been created.")
    else:
        raise ValueError("RUN.WORKFLOW in main.yml is not apps nor end-to-end")

def main():
    """
    Given request file with the information relevant to run the applications and a jobs template file, it dynamically creates a 
    jobs.yml file which can be run as application workflow.

    """
    # Open files
    file_mother_request = "mother_request.yml"
    file_jobs = "jobs_template.yml_tmp"
    app_list_source = "../../../conf/main.yml" 

    # Get data from inside:
    with open(file_mother_request, 'r') as f:
        all_requests = yaml.safe_load(f)

    # Extract GSV request from YAML file
    with open(file_jobs, 'r') as f:
        jobs = yaml.safe_load(f)

    # Get list of apps that we want to run:
    with open(app_list_source, 'r') as f:
        main_yml = yaml.safe_load(f)

    # Modify jobs accordingly to mother req

    app_available = list(all_requests.keys()) #apps available in the mother request
    app_requested = main_yml['APP']['NAMES']
    app_chunk_unit = main_yml['EXPERIMENT']['CHUNKSIZEUNIT']
    app_chunk = main_yml['EXPERIMENT']['CHUNKSIZE']

    if str(app_chunk_unit) == "day":
        jobs['JOBS']['DN']['SPLITS'] = 1 * int(app_chunk)
    if str(app_chunk_unit) == "month":
        jobs['JOBS']['DN']['SPLITS'] = 31 * int(app_chunk)
    if str(app_chunk_unit) == "year":
        jobs['JOBS']['DN']['SPLITS'] = 366 * int(app_chunk)


    # Check that all requested apps have a request defined in mother_request.yml
    check_elements_in_list(app_requested, app_available)

    # set requested variables to create the corresponding jobs.yml
    app_names = app_requested

    ## replace app names
    jobs['RUN']['APP_NAMES'] = app_names

    ## fill OPA fields
    opa_names = list()
    for app in list(app_names):
        num_var = len(all_requests[str(app)])
        for i in range(1,num_var + 1):
            opa_names.append(f'{app.lower()}_{i}')

    jobs['RUN']['OPA_NAMES'] = opa_names 

    jobs['JOBS']['OPA']['FOR']['SPLITS'] = str([jobs['JOBS']['DN']['SPLITS']] * len(opa_names))

    ### OPA dependencies 
    list_of_dict=list()
    jobs_opa_for_dependencies = list()
    for opa in list(opa_names):
        num_var = 1
        
        for i in range(1, num_var + 1):
            tmp_dict = [{'DN': {'SPLITS_FROM': {'all': {'SPLITS_TO': '"[1:%JOBS.DN.SPLITS%]*\\\\1"'}}}, f'OPA_{opa.upper()}': {'SPLITS_FROM': {'all': {'SPLITS_TO': 'previous'}}}}]
       
        result_dict = {key: value for d in tmp_dict for key, value in d.items()}
        jobs_opa_for_dependencies.append(result_dict)

    # Put everything in a jobs.yml
    jobs['JOBS']['OPA']['FOR']['DEPENDENCIES'] = jobs_opa_for_dependencies

    ### Splits
    if main_yml['RUN']['WORKFLOW'] == "apps":
        jobs['JOBS']['APP']['FOR']['SPLITS'] = "1" 
    else:
        jobs['JOBS']['APP']['FOR']['SPLITS'] = str([jobs['JOBS']['DN']['SPLITS']] * len(app_names))

    ### App dependencies
    jobs_app_for_dependencies = list()
    for app in list(app_names):
        num_var = len(all_requests[str(app)])
        jobs_app_for_dependencies_tmp = list()
        for i in range(1,num_var + 1):
            jobs_app_for_dependencies_tmp.append({f'OPA_{app.upper()}_{i}': {'SPLITS_FROM': {'all': {'SPLITS_TO': 'all'}}}}) 
        jobs_app_for_dependencies_tmp.append({f'APP_{app.upper()}': {'SPLITS_FROM': {'all': {'SPLITS_TO': 'previous'}}}})
        #TODO: \\1 is the frequency app runs (1=1 day, 2=2 days). Possibly some other modifications needed.
        list_of_dicts = jobs_app_for_dependencies_tmp
        result_dict = {key: value for d in list_of_dicts for key, value in d.items()}
        jobs_app_for_dependencies.append(result_dict)


    # Put everything in a jobs.yml
    jobs['JOBS']['APP']['FOR']['DEPENDENCIES'] = jobs_app_for_dependencies
    
    #wrapper configuration: TODO
    #jobs['WRAPPERS']['MIN_WRAPPED'] = len(jobs['RUN']['OPA_NAMES'])
    #jobs['WRAPPERS']['MAX_WRAPPED'] = len(jobs['RUN']['OPA_NAMES'])

    # create jobs_XXX.yml:
    write_files(jobs, main_yml)

if __name__ == "__main__":
    main()

