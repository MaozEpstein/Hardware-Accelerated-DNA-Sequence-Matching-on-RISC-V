REM Based on Vivado 2023 Automatically generated batch file
REM ALex Grinshpun 2023
REM Provided AS IS without WARRANTIES of any kind nor explicit neither implied
REM SPDX-License-Identifier: Apache-2.0
REM Copyright 2019-2020 Western Digital Corporation or its affiliates.
REM
REM Licensed under the Apache License, Version 2.0 (the "License");
REM you may not use this file except in compliance with the License.
REM You may obtain a copy of the License at
REM
REM http://www.apache.org/licenses/LICENSE-2.0
REM
REM Unless required by applicable law or agreed to in writing, software
REM distributed under the License is distributed on an "AS IS" BASIS,
REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM See the License for the specific language governing permissions and
REM limitations under the License.

REM *************UPDATE VIVADO INSTALL PATH ***************************
REM TOOLS SETUP
SET VIVADO_INSTALL=C:\Xilinx\Vivado\2023.2
REM *******************************************************************
SET PATH=%VIVADO_INSTALL%\bin;%VIVADO_INSTALL%\lib\win64.o;%PATH%
SET XILINX_VIVADO=%VIVADO_INSTALL%
SET PYTHON_VER=python-3.8.3
SET PYTHON_PATH=%VIVADO_INSTALL%\tps\win64\%PYTHON_VER%
REM ********************************************************************


REM ********************************************************************
REM PROJECT SETUP
SET RVFPGATOP=rvfpgasim_fpga
REM Path to compiled dir containing bin file
SET path_to_bin=..\Output\Debug\Exe
REM Path to SW source dir
SET path_to_source=..\Source
REM Path to SEGGER ES Project file *.emProject
SET path_to_project=..\
SET VIVADO_XPR_NAME=nexysA7card
SET VIVADO_SIM_PATH=..\..\..\vivado\%VIVADO_XPR_NAME%.sim\sim_1\behav\xsim
REM ********************************************************************

IF EXIST "error.build" ( del error.build)
IF EXIST "vhFileError" ( del vhFileError)
IF EXIST "vhFileName"  ( del vhFileName)
IF EXIST "simulate*.log"  ( del simulate*.log)

SET SimulationDIR=%cd%
SET vhFileError=0

echo "****************** CREATE MEM FILE FROM SEGGER BUILD *******************"
%PYTHON_PATH%\python.exe .\makehex.py %path_to_project% %path_to_bin% %path_to_source% > makehex.log
if %errorlevel%==1 SET vhFileError=1
if %vhFileError%==1 echo "vhFileError %vhFileError%"
if %vhFileError% == 1 (goto :END)
if EXIST vhFileName (
	SET /p TESTVH=<vhFileName
) else (
	echo "no vhFileName. Exitting:
	goto :END2
)
xcopy /Y %TESTVH% %VIVADO_SIM_PATH%

echo "****************** %SimulationDIR% *******************"
SET VLOG=%SimulationDIR%\%RVFPGATOP%_vlog.log
SET XELABLOG=%SimulationDIR%\%RVFPGATOP%_elaborate.log
SET SIMUALTIONLOG=%SimulationDIR%\%RVFPGATOP%_simulation.log

IF EXIST %VLOG%				( del %VLOG%)
IF EXIST %XELABLOG%			( del %XELABLOG%)
IF EXIST %SIMUALTIONLOG%	( del %SIMUALTIONLOG%)

IF EXIST %RVFPGATOP%_vlog.prj (
	echo "Copy Project file %RVFPGATOP%_vlog.prj to %VIVADO_SIM_PATH%"
	xcopy /Y %RVFPGATOP%_vlog.prj %VIVADO_SIM_PATH%
)

pushd %VIVADO_SIM_PATH%
IF NOT EXIST %RVFPGATOP%_vlog.prj (
	echo "Project file %RVFPGATOP%_vlog.prj  doesn't exist. Exitting ..."
	pause
	exit
)

IF EXIST "xsim.dir" ( del /s /q xsim.dir)


echo "xvlog --incr --relax -L uvm -prj %RVFPGATOP%_vlog.prj"
call xvlog --incr --relax  -L uvm -prj %RVFPGATOP%_vlog.prj -log %VLOG%
echo "Check for VLOG compile errors ..............................................."
IF NOT EXIST %VLOG% (
	echo "No %VLOG% exitting" 
	pause 
	exit
)
echo "****************** %VLOG% *******************"
for /f "delims=" %%i in ('findstr /c:"ERROR:" %VLOG% ^| find /c  /v ""') do set /a VLOG_COMPILE_ERROR=%%i
echo "******************** VLOG COMPILE ERRORS %VLOG_COMPILE_ERROR% **********************"
if  %VLOG_COMPILE_ERROR% GTR 0 (
 echo "VLOG COMPILE ERROR. Exitting ..."
 echo " Check in %RVFPGATOP%_vlog.prj"
 pause 
 exit
 )

echo "****************** ELABORATION *******************"	
echo "xelab --incr --debug typical --relax --mt 2 -d "JTAG_EXTERNAL=1" -d "XSIM=1" -d "SIMULATION=1" -L xil_defaultlib -L uvm -L unisims_ver -L unimacro_ver -L secureip -L xpm --snapshot %RVFPGATOP%_behav xil_defaultlib.%RVFPGATOP% xil_defaultlib.glbl -log %XELABLOG%"
call xelab  --incr --debug typical --relax --mt 2 -d "JTAG_EXTERNAL=1" -d "XSIM=1" -d "SIMULATION=1" -L xil_defaultlib -L uvm -L unisims_ver -L unimacro_ver -L secureip -L xpm --snapshot %RVFPGATOP%_behav xil_defaultlib.%RVFPGATOP% xil_defaultlib.glbl -log %XELABLOG%
echo "Check for ELABORATION compile errors ..............................................."
IF NOT EXIST %XELABLOG% (
	echo "No %XELABLOG%  exitting" 
	pause 
	exit
)
echo "****************** %XELABLOG% *******************"
for /f "delims=" %%i in ('findstr /c:"ERROR:" %XELABLOG% ^| find /c  /v ""') do set /a XELABLOG_ERROR=%%i
echo "******************** XELAB  ERRORS %VLOG_COMPILE_ERROR% **********************"
if  %XELABLOG_ERROR% GTR 0 (
 echo "XELAB COMPILE ERROR. Exitting ..."
 echo " Check in %RVFPGATOP%_vlog.prj"
 pause 
 exit
 )

echo "****************** SIMULATOR *******************"
echo "xsim %RVFPGATOP%_behav -key {Behavioral:sim_1:Functional:%RVFPGATOP%} -tclbatch %RVFPGATOP%.tcl -view %RVFPGATOP%_behav.wcfg -log simulate.log -testplusarg ram_init_file=%TESTVH% -testplusarg "rom_init_file=boot_main.vh"
REM call xsim  %RVFPGATOP%_behav -gui -key {Behavioral:sim_1:Functional:%RVFPGATOP%} -tclbatch %RVFPGATOP%.tcl -wdb %SimulationDIR%\%RVFPGATOP%_behav.wdb -view %SimulationDIR%\%RVFPGATOP%_behav.wcfg -log %SIMUALTIONLOG% -testplusarg "ram_init_file=%TESTVH%" -testplusarg "rom_init_file=boot_main.vh"
call xsim  %RVFPGATOP%_behav -gui -key {Behavioral:sim_1:Functional:%RVFPGATOP%} -tclbatch %RVFPGATOP%.tcl -wdb %SimulationDIR%\%RVFPGATOP%_behav.wdb -view %SimulationDIR%\%RVFPGATOP%_behav.wcfg -log %SIMUALTIONLOG% -testplusarg "ram_init_file=%TESTVH%"
popd
if "%errorlevel%"=="1" goto :END
if "%errorlevel%"=="0" goto :SUCCESS
:END
echo "Build Segger" > error.build
echo ""******************** ERROR: RUN Build Seggger "********************"
pause
IF EXIST %TESTVH% ( del %TESTVH%)
exit 1
:END2
exit 1
:SUCCESS
exit 0