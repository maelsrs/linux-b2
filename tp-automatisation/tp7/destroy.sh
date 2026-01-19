#!/bin/bash

terraform destroy -auto-approve
rm -f inventory.ini
echo "Infrastructure detruite."
