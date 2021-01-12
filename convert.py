import csv
import json

settings_file = '/home/mplageman/autobench/settings-1.csv'

def settings_to_json(settings_file, to_file):
    output_dict = {}
    with open(settings_file, newline='') as csvfile:
        reader = csv.DictReader(csvfile, delimiter=',')
        for row in reader:
            output_dict[row['vm_disk']] = row

    if not to_file:
        return json.dumps(output_dict)

    output_file = settings_file.split('.')[0] + '.json'
    with open(output_file, 'w') as outfile:
        json.dump(output_dict, outfile)
    return output_file

settings_to_json(settings_file=settings_file, to_file=True)
