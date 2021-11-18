import argparse
import logging
import json
import myutils
import sys
import collections
import re


def main():
    num_error = 0  # This variable is used for counting the number of errors (no warnings) detected by the validator
    my_parser = argparse.ArgumentParser(description='Metadata package validator')
    my_parser.add_argument('-f', '--file', action="store", dest="input_filename", type=str, help='input filename')
    args = my_parser.parse_args()

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    # create file handler which logs even debug messages
    fh = logging.FileHandler('package_metadata_validator.log', encoding="utf-8")
    # create console handler which logs even debug messages
    ch = logging.StreamHandler()
    # create formatter and add it to the handlers
    formatter = logging.Formatter('* %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    # add the handlers to the logger
    logger.addHandler(fh)
    logger.addHandler(ch)

    logger.info('-------------------------------------Starting validation-------------------------------------')

    try:
        open(args.input_filename)
    except IOError:
        print("Please provide a valid filename")
        exit(-1)
    else:
        with open(args.input_filename, mode='r', encoding="utf-8") as json_file:
            package = json.load(json_file)

    # -------------------------------------

    # Validation for options
    o_mq_2 = {}
    if "options" not in package:
        package["options"] = []
    for option in package["options"]:
        # Group options by optionSet (for O-MQ-2)
        optionSet = option["optionSet"]["id"]
        if optionSet in o_mq_2:
            o_mq_2[optionSet].append(option["sortOrder"])
        else:
            o_mq_2[optionSet] = list()
            o_mq_2[optionSet].append(option["sortOrder"])

    # O-MQ-2: Expected sortOrder for options of an optionSet (starts at 1 and ends at the size of the list of options)
    for optionSet_uid, sortOrders in o_mq_2.items():
        sortOrders.sort()  # Order array of sortOrders

        optionSet_size = len(sortOrders)
        if (sortOrders[0] == 1) and (sortOrders[optionSet_size - 1] == optionSet_size):
            pass  # Everything is OK
        else:
            optionSet_name = myutils.get_name_by_type_and_uid(package=package, resource_type="optionSets", uid=optionSet_uid)
            message = "O-MQ-2 - The optionSet '" + optionSet_name + "' (" + optionSet_uid + ") has errors in the sortOrder. Current sortOrder: "+", ".join([str(i) for i in sortOrders])
            logging.error(message)
            num_error += 1

    # -------------------------------------

    # OG-MQ-1. All options in optionGroups must belong to an optionSet
    if "optionGroups" not in package:
        package["optionGroups"] = []
    option_uids_in_option_groups = myutils.json_extract_nested_ids(package["optionGroups"], "options")

    if "optionSets" not in package:
        package["optionSets"] = []
    option_uids_in_optionset = myutils.json_extract_nested_ids(package["optionSets"], "options")

    for option_uid in option_uids_in_option_groups:
        if option_uid not in option_uids_in_optionset:
            logger.error(f"OG-MQ-1 - Option in OptionGroup but not in OptionSet. Option '{myutils.get_name_by_type_and_uid(package, 'options', option_uid)}' ({option_uid})")

    # -------------------------------------

    def check_external(k, v):
        if k == "externalAccess" and v is True:
            logger.error("SHST-MQ-1 - There is a resource with external access. Suggestion: use grep command for finding '\"externalAccess\": true'")

    myutils.iterate_complex(package, check_external)

    def check_favorites(k, v):
        if k == "favorites" and v:
            logger.error("ALL-MQ-16. There is a reference to user ("+','.join(v)+") that saved the resource as favourite. Suggestion: use grep command for finding")

    myutils.iterate_complex(package, check_favorites)

    # -------------------------------------

    # Program Rules
    if "programRules" not in package:
        package["programRules"] = []
    for pr in package["programRules"]:
        # PR-ST-3: Program Rule without action
        if len(pr["programRuleActions"]) == 0:
            logger.error(f"PR-ST-3 Program Rule '{pr['name']}' ({pr['id']}) without Program Rule Action")
            num_error += 1

    # PRV-MQ-1 More than one PRV with the same name
    if "programRuleVariables" not in package:
        package["programRuleVariables"] = []
    prv_names = [prv["name"] for prv in package["programRuleVariables"]]
    if len(prv_names) != len(set(prv_names)):
        logger.error("PRV-MQ-1 - More than one PRV with the same name: "+str([item for item, count in collections.Counter(prv_names).items() if count > 1]))

    forbidden = ["and", "or", "not"]  # (dhis version >= 2.34)
    for prv in package["programRuleVariables"]:

        if any([" "+substring+" " in prv["name"] for substring in forbidden]) or \
           any([prv["name"].startswith(substring+" ") for substring in forbidden]) or \
           any([prv["name"].endswith(" "+substring) for substring in forbidden]):
            message = f"PRV-MQ-2: The PRV '{prv['name']}' ({prv['id']}) contains 'and/or/not'"
            logger.error(message)

        if not bool(re.match("^[a-zA-Z\d_\-\.\ ]+$", prv["name"])):
            message = f"PRV-MQ-2: The PRV '{prv['name']}' ({prv['id']}) contains unexpected characters"
            logger.error(message)


    # PR-ST-4: Data element associated to a program rule action MUST belong to the program that the program rule is associated to.
    de_in_program = []
    if "programStages" not in package:
        package["programStages"] = []
    for ps in package["programStages"]:
        for psde in ps["programStageDataElements"]:
            de_in_program.append(psde["dataElement"]["id"])

    if "programRuleActions" not in package:
        package["programRuleActions"] = []
    for pra in package["programRuleActions"]:
        if "dataElement" in pra and pra["dataElement"]["id"] not in de_in_program:
            pr_uid = pra['programRule']['id']
            pr_name = myutils.get_name_by_type_and_uid(package, 'programRules', pr_uid)
            de_uid = pra['dataElement']['id']
            de_name = myutils.get_name_by_type_and_uid(package, 'dataElements', de_uid)
            logging.error(f"PR-ST-4 Program Rule '{pr_name}' ({pr_uid}) in the PR Action uses a DE '{de_name}' ({de_uid}) that does not belong to the associated program.")

    # PR-ST-5: Tracked Entity Attribute associated to a program rule action MUST belong to the program/TET that the program rule is associated to.
    teas_program = []
    if "programs" in package:
        program = package["programs"][0]
        teas = program["programTrackedEntityAttributes"]
        if "trackedEntityType" in program:
            trackedEntityType_uid = program["trackedEntityType"]["id"]
            for tet in package["trackedEntityTypes"]:
                if tet["id"] == trackedEntityType_uid:
                    teas = teas + tet["trackedEntityTypeAttributes"]
        for tea in teas:
            teas_program.append(tea["trackedEntityAttribute"]["id"])

        for pra in package["programRuleActions"]:
            if "trackedEntityAttribute" in pra and pra["trackedEntityAttribute"]["id"] not in teas_program:
                pr_uid = pra['programRule']['id']
                pr_name = myutils.get_name_by_type_and_uid(package, 'programRules', pr_uid)
                tea_uid = pra['trackedEntityAttribute']['id']
                tea_name = myutils.get_name_by_type_and_uid(package, 'trackedEntityAttribute', tea_uid)
                logging.error(f"PR-ST-5 Program Rule '{pr_name}' ({pr_uid}) in the PR Action uses a TEA '{tea_name}' ({tea_uid}) that does not belong to the associated program.")


    # code
    PATTERN_OPTION_CODE = re.compile("^([0-9A-Z_\|\-\.]+)+$")
    PATTERN_CODE = re.compile("^([0-9A-Z_]+)+$")
    resources_with_code = ['dashboards', 'dataSets', 'programs', 'indicatorGroups', 'dataElementGroups', 'predictorGroups', 'validationRuleGroups', 'userGroups', 'options']
    for resource_type in resources_with_code:
        if resource_type not in package:
            continue

        for resource in package[resource_type]:
            if "code" not in resource:
                message = f"ALL-MQ-17- Missed code field in {resource_type} (name='{resource['name']}' uid={resource['id']})"
                logger.warning(message)
            else:
                # ALL-MQ-18: Codes MUST be upper case ASCII (alphabetic A-Z), and the symbols '_' (underscore),'-' (hyphen),'.' (dot),'|' (Bar o Pipe)
                if "\t" in resource["code"]:
                    message = f"ALL-MQ-18- Tab character in code='{resource['code']}' (resource type='{resource_type}' name='{resource['name']}' uid={resource['id']})"
                    logger.error(message)
                    resource["code"] = resource["code"].replace("\t", "")
                    num_error += 1
                if resource_type == "options":
                    if not PATTERN_OPTION_CODE.search(resource["code"]):
                        message = f"ALL-MQ-18- Invalid code='{resource['code']}' (resource type='{resource_type}' name='{resource['name']}' uid={resource['id']})"
                        logger.error(message)
                        num_error += 1
                else:
                    if not PATTERN_CODE.search(resource["code"]):
                        message = f"ALL-MQ-18- Invalid code='{resource['code']}' (resource type='{resource_type}' name='{resource['name']}' uid={resource['id']})"
                        logger.error(message)
                        num_error += 1

    logger.info('-------------------------------------Finished validation-------------------------------------')

    #  See https://stackoverflow.com/questions/15435652/python-does-not-release-filehandles-to-logfile
    handlers = logger.handlers[:]
    for handler in handlers:
        handler.close()
        logger.removeHandler(handler)

    return num_error


if __name__ == '__main__':
    num_error = main()
    # if the number of errors > 0, exit with code -1
    if num_error:
        sys.exit(-1)
