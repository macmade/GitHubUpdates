#-------------------------------------------------------------------------------
# The MIT License (MIT)
# 
# Copyright (c) 2017 Jean-David Gadina - www.xs-labs.com
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------


# Check for the XSDocgen utility
_HAS_XSDOCGEN := $(shell if [ -f "/usr/local/bin/XSDocgen" ]; then echo true; else echo false; fi )

#-------------------------------------------------------------------------------
# Built-in targets
#-------------------------------------------------------------------------------

# Declaration for phony targets, to avoid problems with local files
.PHONY: all

#-------------------------------------------------------------------------------
# Phony targets
#-------------------------------------------------------------------------------

# Documentation
all:
	
ifeq ($(_HAS_XSDOCGEN),true)
	@echo $(call _PRINT,XSDoc,universal,Generating the documentation)
	@/usr/local/bin/XSDocgen \
	@    --clear \
	@    --source ../GitHubUpdates \
	@    --output . \
	@    --project-name "GitHubUpdates" \
	@    --project-copyright "XS-Labs &copy; %Y - All Rights Reserved" \
	@    --project-version "0.0.0-0" \
	@    --project-timezone "Europe/Zurich" \
	@    --company-name "XS-Labs" \
	@    --company-url "http://www.xs-labs.com/" \
    @    --page-home "Pages/Home.inc.php" \
	@    --source-root-prefix "/GitHubUpdates/" \
	@    --google-analytics "UA-51035898-4" "xs-labs.com" \
	@    --google-analytics-display-features
else
	@echo $(call _PRINT,XSDoc,universal,Skipping documentation generation - XSDocgen is not installed)
endif
