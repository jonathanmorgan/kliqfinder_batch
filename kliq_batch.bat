@ECHO OFF

ECHO.
ECHO kliq_batch.bat version 0.4
ECHO.

REM turn on local variables, enable shell extensions
VERIFY OTHER 2>nul
SETLOCAL ENABLEEXTENSIONS
IF ERRORLEVEL 1 echo Unable to enable extensions

REM CONSTANTS-ish
SET list_delimiter=;
SET current_date=%Date%
SET current_time=%Time:^:=.%

REM first, read the file path and executable
SET arg1=%1
SET arg2=%2

REM ============================================================================
REM Process input arguments.
REM ============================================================================

REM === path to list of files to process
SET file_list_path=%1

REM does argument 1 contain the executable choice (1 or 2)?  Bad, but need to check.
IF /I "%arg1%" EQU "1" ( GOTO :Executable_in_arg_1 )
IF /I "%arg1%" EQU "2" ( GOTO :Executable_in_arg_1 )
GOTO :Check_for_list_path

:Executable_in_arg_1
SET arg2=%1
SET file_list_path=%2

:Check_for_list_path
REM is file list path empty?
IF /I "%file_list_path%" EQU "" SET /P file_list_path="Please enter the path of a file that contains paths of .list files to process, one to a line.  If the path contains spaces, please put double quotes around it: "
IF EXIST "%file_list_path%" GOTO :List_path_ok

ECHO.
ECHO Could not find file %file_list_path%.
ECHO.
SET file_list_path=
GOTO :Check_for_list_path

:List_path_ok
ECHO.

REM === executable - start with value in arg2 (might be first or second argument, depending on what the user passed in).
SET executable=%arg2%

:Prompt_for_executable
REM Executable set? (1=kliqfind.exe, 2=kfr.exe)?
IF /I "%executable%" EQU "" SET /P executable="Choose the kliq program to run (1 or <Enter>: kliqfind.exe - single-mode data; 2: kfr.exe - two-mode data): "

REM deal with value.
IF /I "%executable%" EQU "1" GOTO :Execute_kliqfind
IF /I "%executable%" EQU "2" GOTO :Execute_kfr
IF /I "%executable%" EQU "" GOTO :Execute_kliqfind 

REM no valid choice, so output what they entered, then send back to prompt.
ECHO.
ECHO Invalid choice (%executable%).
ECHO.
SET executable=
GOTO :Prompt_for_executable

REM set executable to kliqfind.exe.
:Execute_kliqfind

SET executable=kliqfind.exe

GOTO :Ready_to_loop

REM set executable to kfr.exe
:Execute_kfr

SET executable=kfr.exe

:Ready_to_loop

ECHO.
ECHO file path: %file_list_path%
ECHO executable: %executable%
ECHO.

REM ============================================================================
REM Loop over list files
REM ============================================================================

REM loop over file whose path is passed in on the command line, in %1.
REM multiple line loop bodies make using variables inside tricky (all are
REM    substituted when loop is started).  Instead, use SETLOCAL to create
REM    separate context for each "CALL", then set up gosub to handle processing.

REM variable to hold list of names of *.place files, separated by semi-colons.
SET place_file_list=

FOR /F "tokens=*" %%A in ( %file_list_path% ) do CALL :Process_file "%%A"

ECHO.
ECHO Finished processing data files with kliqfinder.

CALL :Aggregate_place_files "%file_list_path%" "%place_file_list%"

GOTO :Turn_off_local

:Turn_off_local

	REM end local variable context
	ENDLOCAL

	GOTO :End

REM -- END Label :Turn_off_local -- 

REM ============================================================================
REM :Process_file
REM Purpose: File processing gosub.
REM Parameters:
REM 0 - path where batch executed (by default).
REM 1 - original file name of data file we are currently processing.
REM ============================================================================

:Process_file

	REM initialize variables
	SET current_path=
	SET original_file_path=
	SET just_path=
	SET just_file_name=
	SET current_place_file=

	REM get path of current working directory
	SET current_path=%~p0
	ECHO current_path: %current_path%

	REM get original file name without any surrounding quotes.
	ECHO argument 1: %1
	SET original_file_path=%~1
	ECHO - original_file_path: %original_file_path%

	REM get just the file name, no path information.
	REM SET just_file_name=%~n1
	REM ECHO -- just_file_name: %just_file_name%
	REM SET just_extension=%~x1
	REM ECHO -- just_extension: %just_extension%
	SET just_file_name=%~nx1
	ECHO -- just file name: %just_file_name%
	
	REM get just the path
	SET just_path=%~p1
	ECHO -- just_path: %just_path%

	REM If there is anything in path, copy file to current directory.
	IF /I NOT "%just_path%" EQU "%current_path%" COPY "%original_file_path%" .\
	
	REM convert any spaces to underscores.
	SET current_file_name=%just_file_name: =_%
	ECHO - current_file_name: %current_file_name%
	
	REM if current not equal to just_file_name, move just_file_name to current_file_name.
	IF /I "%just_file_name%" NEQ "%current_file_name%" MOVE "%just_file_name%" "%current_file_name%"

	REM call the kliqfinder program.
	"C:\KLIQFIND\%executable%" %current_file_name%
	
	REM if paths are different, move results back to source directory.

	REM Add 6 spaces to right side of string, since the kliqfind program adds
	REM    spaces to right of output file prefix if file name is less than six
	REM    characters long.
	SET "move_prefix=%current_file_name%      "
	
	REM Parse off the six left-most characters (kliqfind.exe just uses 1st six
	REM    for output file prefix).
	SET move_prefix=%move_prefix:~0,6%
	
	REM could, at this point, loop over all files that match and MOVE them so
	REM    they have the full filename as prefix, not just the first six
	REM    characters.

	REM Derive current place file name.
	SET current_place_file=%move_prefix%.place
	IF /I "%just_path%" NEQ "%current_path%" SET current_place_file=%just_path%%current_place_file%

	REM add the current .place file to the .place file list.
	REM if not empty, add a semi-colon, then next item.
	IF /I "%place_file_list%" NEQ "" SET "place_file_list=%place_file_list%%list_delimiter%%current_place_file%"
	
	REM if empty, just add item (and check second, so we don't add it, then check for not empty).
	IF /I "%place_file_list%" EQU "" SET place_file_list=%current_place_file%

	REM if copied from different path, move output files there.
	IF /I "%just_path%" NEQ "%current_path%" MOVE "%move_prefix%.*" "%just_path%"
	
	REM delete the copy of the data file, also?
	IF /I "%just_path%" NEQ "%current_path%" DEL %current_file_name%

	GOTO :End

REM -- END Label :Process_file -- 

REM ============================================================================
REM :Aggregate_place_files
REM Purpose: Accepts a list of *.place files (output by kliqfind.exe) and the
REM    name of the file in which the list of data files to process was stored.
REM    pipes each of the files to a single file in the current directory
REM    named the same as the original file that contained the data file paths
REM    to process.
REM Parameters:
REM 0 - path where batch executed (by default).
REM 1 - original file name of data file list file we are currently processing.
REM 2 - string that contains the list of place files
REM ============================================================================

:Aggregate_place_files

	ECHO.
	ECHO Aggregating place files into one file, named same as file with list of data files, but with ".place" extension.  If that file already exists, it will be moved to a new file named "place_archive-<date>-<time>-<original_file_name>", so we don't accidentally overwrite old results.
	ECHO.
	ECHO - Original list file: %1
	ECHO - Place file list: %2

	REM declare variables
	SET list_file_name=
	SET list_file_directory=
	SET output_file_name=
	SET backup_file_name=
	SET place_file_list=
	
	REM get just the name of the original list file.
	SET list_file_name=%~n1
	SET list_file_directory=%~p1
	
	REM name the output file %list_file_name%.place
	SET output_file_name=%list_file_name%.place
	
	REM see if output file already exists.  If so, copy it off and make a new
	REM    file.
	SET backup_file_name=place_archive-%current_date%-%current_time%-%output_file_name%

	REM clean up colons, spaces, and slashes in date and time.
	SET backup_file_name=%backup_file_name:/=.%
	SET backup_file_name=%backup_file_name: =_%
	SET backup_file_name=%backup_file_name::=.%

	ECHO - Output file name: "%output_file_name%"
	ECHO - Place archive file name (if needed):
	ECHO     "%backup_file_name%"
	IF EXIST "%list_file_directory%%output_file_name%" MOVE "%list_file_directory%%output_file_name%" "%list_file_directory%%backup_file_name%"
	
	REM now that housekeeping with preserving old files is done, add
	REM    the directory to the overall output file name.
	SET output_file_name=%list_file_directory%%output_file_name%
	
	REM now, loop over items in the list, appending each to file
	REM    %output_file_name%  First, grab the place file list and strip off quotation marks.
	SET place_file_list=%~2

	REM call recursive gosub to process list.
	CALL :Iterate_over_place_files "%place_file_list%"
	
	ECHO.
	ECHO Finished aggregating place files.

	GOTO :End

REM -- END Label :Aggregate_place_files -- 

:Iterate_over_place_files

	REM declare variables
	set list_IN=%1
	set list_IN=%list_IN:"=%
	
	ECHO.
	ECHO In loop over place files:
	ECHO - list_IN: %list_IN%
	ECHO - output_file_name: "%output_file_name%"

	REM Loop over tokens 
	FOR /f "tokens=1* delims=%list_delimiter%" %%a IN ( "%list_IN%" ) DO (
		REM if we got a file name, append it to output file.
		IF NOT "%%a" == "" (
			ECHO - Appending contents of file "%%a"
			TYPE "%%a" >> "%output_file_name%"
		)
		REM if we have something in "rest of string" (%%b), recurse.
		IF NOT "%%b" == "" CALL :Iterate_over_place_files "%%b"
	)

	GOTO :End
	
REM -- END Label :Iterate_over_place_files --

:End