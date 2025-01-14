" Helper class to talk to ADO REST API for Git and build pipeline operations
" minor change
CLASS ZCL_UTILITY_ABAPTOGIT_ADO DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

PUBLIC SECTION.

    " sync status file name to keep track on last sync-ed TR
    CONSTANTS:  c_sync_status_file   TYPE string VALUE '.sync_status.json'.

    " payload for ADO REST API to create a push
    TYPES: BEGIN OF ts_item,
            path TYPE string,
           END OF ts_item.
    TYPES: BEGIN OF ts_newcontent,
            content     TYPE string,
            contentType TYPE i,
           END OF ts_newcontent.
    TYPES: BEGIN OF ts_change,
            changeType  TYPE i,
            item        TYPE ts_item,
            newContent  TYPE ts_newcontent,
           END OF ts_change.
    TYPES: tty_changes TYPE TABLE OF ts_change WITH KEY changeType.
    TYPES: BEGIN OF ts_commit,
            changes TYPE tty_changes,
            comment TYPE string,
           END OF ts_commit.
    TYPES: tty_commits TYPE TABLE OF ts_commit WITH KEY comment.
    TYPES: BEGIN OF ts_refupdate,
            name        TYPE string,
            oldObjectId TYPE string,
           END OF ts_refupdate.
    TYPES: tty_refupdates TYPE TABLE OF ts_refupdate WITH KEY name.
    TYPES: BEGIN OF ts_push_json_req,
            commits     TYPE tty_commits,
            refUpdates  TYPE tty_refupdates,
           END OF ts_push_json_req.

    " list of TR IDs to sync to Git
    TYPES: tty_trids TYPE TABLE OF string.

    " payload of JSON file in Git repo root folder to mark down sync status
    TYPES: BEGIN OF ts_sync_status,
            trid        TYPE string,
            mode        TYPE string,
            updatedate  TYPE d,
            updatetime  TYPE t,
           END OF ts_sync_status.

    " constructor
    " iv_username - VSO user name as email address
    " iv_pat - VSO personal access token, could be generated from VSO portal per user
    " iv_orgid - organization ID, like the name "org" in <org>.visualstudio.com
    " iv_repoid - Git repo ID
    " iv_project - project like "OneITVSO"
    " io_objtelemetry - class object for telemetry
    " iv_methtelemetry - method name for telemetry
    " for telemetry, the method will be invoked with parameters iv_message as string (for message content) and iv_kind as string (for category)
    METHODS constructor
        IMPORTING
            iv_username         TYPE string
            iv_pat              TYPE string
            iv_orgid            TYPE string
            iv_repoid           TYPE string
            iv_project          TYPE string
            io_objtelemetry     TYPE REF TO object OPTIONAL
            iv_methtelemetry    TYPE string OPTIONAL.

    " push the ABAP objects to Git for a TR
    " iv_trid - TR ID to push to Git
    " iv_branch - branch name to push the changes to
    " iv_comment - commit comment retrieved from get_tr_commit_objects
    " iv_rootfolder - the root folder in Git local clone for ABAP objects to add to, shared by all packages in SAP
    " it_commit_objects - table of ABAP objects to commit to Git, retrieved from get_tr_commit_objects
    " ev_commitid - commit ID of push done
    METHODS push_tr_commit_objects
        IMPORTING
            iv_trid             TYPE string
            iv_branch           TYPE string
            iv_comment          TYPE string
            iv_rootfolder       TYPE string DEFAULT '/src/'
            it_commit_objects   TYPE ZCL_UTILITY_ABAPTOGIT_TR=>tty_commit_object
        EXPORTING
            ev_commitid         TYPE string
        RETURNING VALUE(rv_success) TYPE string.

    " get IDs of TRs after a given TR, or ID of latest TR if not given
    " iv_fromtrid - TR ID to start sync-ing for its next TR, or indicate to get latest TR ID if not provided
    " et_trids - list of TR IDs retrieved
    CLASS-METHODS get_trs
        IMPORTING
            iv_fromtrid   TYPE string OPTIONAL
        EXPORTING
            et_trids      TYPE tty_trids.

    " construct source code file name in Git repo from ABAP code object name
    " iv_commit_object - ABAP object to commit
    " rv_name - file name to present the ABAP object in Git repo
    CLASS-METHODS build_code_name
        IMPORTING
            iv_commit_object    TYPE ZCL_UTILITY_ABAPTOGIT_TR=>ts_commit_object
        RETURNING VALUE(rv_name) TYPE string.

    " get sync status from the sync status file (by fetching item content from ADO REST API or local disk file)
    " iv_filecontent - file content of the sync status file
    " ev_sync_status - structure of the sync status
    CLASS-METHODS load_sync_status
        IMPORTING
            iv_filecontent  TYPE string
        EXPORTING
            ev_sync_status  TYPE ts_sync_status
        RETURNING VALUE(rv_success) TYPE string.

    " save constructed sync status file to local disk
    " iv_mode - active/latest version mode
    " iv_file - sync status file name
    " iv_trid - TR ID to specify in sync status
    CLASS-METHODS save_sync_status
        IMPORTING
            iv_mode TYPE string
            iv_file TYPE string
            iv_trid TYPE string OPTIONAL
        RETURNING VALUE(rv_success) TYPE string.

    " fetch item content by ADO REST API
    " iv_branch - branch name
    " iv_itempath - object path in Git repo
    " ev_content - object content retrieved
    METHODS get_item_ado
        IMPORTING
            iv_branch   TYPE string
            iv_itempath TYPE string
        EXPORTING
            ev_content  TYPE string
        RETURNING VALUE(rv_success) TYPE string.

PROTECTED SECTION.

PRIVATE SECTION.

    CONSTANTS: c_host               TYPE string VALUE 'https://dev.azure.com/',
               c_head               TYPE string VALUE 'refs/heads/',
               c_null_objectid_ref  TYPE string VALUE '0000000000000000000000000000000000000000'.

    " credential for ADO REST APIs
    DATA username TYPE string.
    DATA pat TYPE string.

    " organization ID, like the name "org" in <org>.visualstudio.com
    DATA orgid TYPE string.
    " Git repo ID
    DATA repoid TYPE string.
    " project name like "OneITVSO"
    DATA project TYPE string.

    " telemetry callback
    DATA oref_telemetry TYPE REF TO object.
    DATA method_name_telemetry TYPE string.

    " construct sync status file content as a mark of which TR current branch sync to
    CLASS-METHODS build_sync_status
        IMPORTING
            iv_mode         TYPE string
            iv_trid         TYPE string OPTIONAL
        EXPORTING
            ev_filecontent  TYPE string.

    " fetch commit ID of a branch by ADO REST API
    METHODS get_commit_ado
        IMPORTING
            iv_branch   TYPE string
        EXPORTING
            ev_commitid TYPE string
        RETURNING VALUE(rv_success) TYPE string.

    " add a change to an ABAP object to ADO REST API body for push
    METHODS build_push_json
        IMPORTING
            iv_filename     TYPE string
            iv_filecontent  TYPE string
            iv_changetype   TYPE i
        CHANGING
            iv_commit       TYPE ts_commit.

    " push changes of a TR to Git by ADO REST API
    METHODS push_ado
        IMPORTING
            iv_branch   TYPE string
            iv_commit   TYPE ts_commit
            iv_commitid TYPE string
        EXPORTING
            ev_commitid TYPE string
        RETURNING VALUE(rv_success) TYPE string.

    " create HTTP client for ADO REST API
    METHODS create_http_client
        IMPORTING
            iv_url      TYPE string
            iv_username TYPE string
            iv_pat      TYPE string
        EXPORTING
            ei_http_client  TYPE REF TO if_http_client
            eo_rest_client  TYPE REF TO cl_rest_http_client
            ei_request      TYPE REF TO IF_REST_ENTITY.

    " make HTTP POST request for ADO REST API
    METHODS http_post
        IMPORTING
            io_rest_client  TYPE REF TO cl_rest_http_client
            ii_request      TYPE REF TO IF_REST_ENTITY
            iv_body         TYPE string
        EXPORTING
            ev_status       TYPE string
            ev_response     TYPE string.

    " make HTTP GET request for ADO REST API
    METHODS http_get
        IMPORTING
            io_rest_client  TYPE REF TO cl_rest_http_client
        EXPORTING
            ev_status       TYPE string
            ev_response     TYPE string.

    " wrapper to make HTTP POST request with object as POST body not yet serialized to JSON and response de-serialized
    METHODS http_post_json
        IMPORTING
            iv_path         TYPE string
            iv_username     TYPE string
            iv_pat          TYPE string
            iv_json         TYPE any
        EXPORTING
            ev_status       TYPE i
            et_entry_map    TYPE /ui5/cl_json_parser=>t_entry_map.

    " wrapper to make HTTP POST request with response de-serialized
    METHODS http_get_json
        IMPORTING
            iv_path         TYPE string
            iv_username     TYPE string
            iv_pat          TYPE string
        EXPORTING
            ev_status       TYPE i
            et_entry_map    TYPE /ui5/cl_json_parser=>t_entry_map.

    " wrapper to write telemetry with the callback registered
    METHODS write_telemetry
        IMPORTING
            iv_message  TYPE string
            iv_kind     TYPE string DEFAULT 'error'.

ENDCLASS.



CLASS ZCL_UTILITY_ABAPTOGIT_ADO IMPLEMENTATION.

  METHOD CONSTRUCTOR.

    me->username = iv_username.
    me->pat = iv_pat.
    me->orgid = iv_orgid.
    me->repoid = iv_repoid.
    me->project = iv_project.

    IF io_objtelemetry IS SUPPLIED.
        me->oref_telemetry = io_objtelemetry.
    ENDIF.

    IF iv_methtelemetry IS SUPPLIED.
        me->method_name_telemetry = iv_methtelemetry.
    ENDIF.

  ENDMETHOD.

  METHOD PUSH_TR_COMMIT_OBJECTS.

    DATA lv_commit_object TYPE ZCL_UTILITY_ABAPTOGIT_TR=>ts_commit_object.
    DATA lv_commit TYPE ts_commit.
    DATA lv_commitid TYPE string.
    DATA lv_changetype TYPE i.
    DATA lv_syncfilecontent TYPE string.
    DATA lv_rootfolder TYPE string.
    DATA lv_synccnt TYPE i.

    lv_rootfolder = iv_rootfolder.
    TRANSLATE lv_rootfolder TO UPPER CASE.

    " fetch the head commit ID for given branch
    rv_success = me->get_commit_ado(
        EXPORTING
            iv_branch = iv_branch
        IMPORTING
            ev_commitid = lv_commitid
             ).
    CHECK rv_success = abap_true.

    " construct commit object list payload for push ADO REST call
    LOOP AT it_commit_objects INTO lv_commit_object.

        " change type for add/edit/delete
        IF lv_commit_object-delflag <> ' '.
            lv_changetype = 16.
        ELSEIF lv_commit_object-verno > 1.
            lv_changetype = 2.
        ELSE.
            lv_changetype = 1.
        ENDIF.

        DATA(lv_code_name) = build_code_name( lv_commit_object ).
        DATA(lv_filepath) = |{ lv_rootfolder }{ lv_commit_object-devclass }/{ lv_code_name }|.

        " add the ABAP object change to the changes section of the payload
        me->build_push_json(
            EXPORTING
                iv_filename = lv_filepath
                iv_filecontent = lv_commit_object-filecontent
                iv_changetype = lv_changetype
            CHANGING
                iv_commit = lv_commit
             ).

        lv_synccnt = lv_synccnt + 1.

    ENDLOOP.

    " update sync status file with the TR id
    build_sync_status(
        EXPORTING
            iv_mode = ZCL_UTILITY_ABAPTOGIT_TR=>c_latest_version
            iv_trid = iv_trid
        IMPORTING
            ev_filecontent = lv_syncfilecontent
             ).
    DATA(lv_syncstatuspath) = |{ lv_rootfolder }{ c_sync_status_file }|.
    me->build_push_json(
        EXPORTING
            iv_filename = lv_syncstatuspath
            iv_filecontent = lv_syncfilecontent
            iv_changetype = 2
        CHANGING
            iv_commit = lv_commit
             ).

    lv_commit-comment = iv_comment.

    me->write_telemetry( iv_message = |{ lv_synccnt } objects to push for TR { iv_trid }| iv_kind = 'info' ).

    " push the changes to Git by ADO REST call
    rv_success = me->push_ado(
        EXPORTING
            iv_branch = iv_branch
            iv_commit = lv_commit
            iv_commitid = lv_commitid
        IMPORTING
            ev_commitid = ev_commitid
             ).

  ENDMETHOD.

  METHOD BUILD_CODE_NAME.
    IF iv_commit_object-objtype = 'FUNC' OR iv_commit_object-objtype2 = 'FUNC'.
        " object in function group named as <function group name>.fugr.<object name>.abap, following abapGit
        rv_name = |{ iv_commit_object-fugr }.fugr.{ iv_commit_object-objname }.abap|.
    ELSEIF iv_commit_object-objtype = 'CINC'.
        " test class named as <class name>.clas.testclasses.abap, following abapGit
        rv_name = |{ iv_commit_object-objname }.clas.testclasses.abap|.
    ELSE.
        " others named as <object name>.<object type, PROG|CLAS|INTF|...>.abap, following abapGit
        rv_name = |{ iv_commit_object-objname }.{ iv_commit_object-objtype }.abap|.
    ENDIF.
  ENDMETHOD.

  METHOD GET_TRS.

    IF iv_fromtrid IS SUPPLIED.
        " fetch TRs later than given released TR
        DATA lv_dat TYPE d.
        DATA lv_tim TYPE t.
        SELECT SINGLE as4date INTO lv_dat FROM e070 WHERE trkorr = iv_fromtrid.
        SELECT SINGLE as4time INTO lv_tim FROM e070 WHERE trkorr = iv_fromtrid.
        SELECT trkorr INTO TABLE @et_trids FROM e070
            WHERE trfunction = 'K' AND trstatus = 'R' AND ( as4date > @lv_dat OR ( as4date = @lv_dat AND as4time > @lv_tim ) )
            ORDER BY as4date ASCENDING, as4time ASCENDING.
    ELSE.
        " fetch latest released TR
        SELECT trkorr FROM e070 INTO TABLE @et_trids UP TO 1 ROWS
            WHERE trfunction = 'K' AND trstatus = 'R'
            ORDER BY as4date DESCENDING, as4time DESCENDING.
    ENDIF.

  ENDMETHOD.

  METHOD BUILD_SYNC_STATUS.
    DATA lv_sync_status TYPE ts_sync_status.
    DATA lt_trids TYPE tty_trids.
    DATA lr_json_serializer TYPE REF TO cl_trex_json_serializer.

    IF iv_trid IS SUPPLIED.
        lv_sync_status-trid = iv_trid.
    ELSEIF iv_mode = ZCL_UTILITY_ABAPTOGIT_TR=>c_latest_version.
        " in active version mode, it's not sync-ed to latest TR but active/latest version of objects
        get_trs( IMPORTING et_trids = lt_trids ).
        lv_sync_status-trid = lt_trids[ 1 ].
    ENDIF.

    lv_sync_status-mode = iv_mode.
    lv_sync_status-updatedate = sy-datum.
    lv_sync_status-updatetime = sy-uzeit.
    CREATE OBJECT lr_json_serializer EXPORTING data = lv_sync_status.
    lr_json_serializer->serialize( ).
    ev_filecontent = lr_json_serializer->get_data( ).
  ENDMETHOD.

  METHOD SAVE_SYNC_STATUS.

    DATA lv_json TYPE string.
    DATA lt_filecontent TYPE TABLE OF string.

    IF iv_trid IS SUPPLIED.
        build_sync_status(
            EXPORTING
                iv_mode = iv_mode
                iv_trid = iv_trid
            IMPORTING
                ev_filecontent = lv_json
                 ).
    ELSE.
        build_sync_status(
            EXPORTING
                iv_mode = iv_mode
            IMPORTING
                ev_filecontent = lv_json
                 ).
    ENDIF.

    APPEND lv_json TO lt_filecontent.
    CALL FUNCTION 'GUI_DOWNLOAD'
          EXPORTING
            filename = iv_file
            filetype = 'ASC'
            write_field_separator = 'X'
          TABLES
            data_tab = lt_filecontent
          EXCEPTIONS
            OTHERS = 1.
    rv_success = abap_true.
    IF sy-subrc <> 0.
        rv_success = abap_false.
    ENDIF.

  ENDMETHOD.

  METHOD LOAD_SYNC_STATUS.
    TRY.
        DATA lo_parse TYPE REF TO /ui5/cl_json_parser.
        CREATE OBJECT lo_parse.
        lo_parse->parse( json = iv_filecontent ).
        DATA(lt_ret_data) = lo_parse->m_entries.
        ev_sync_status-trid = lt_ret_data[ name = 'trid' ]-value.
        ev_sync_status-mode = lt_ret_data[ name = 'mode' ]-value.
        ev_sync_status-updatedate = lt_ret_data[ name = 'updatedate' ]-value.
        ev_sync_status-updatetime = lt_ret_data[ name = 'updatetime' ]-value.
        rv_success = abap_true.
    CATCH /ui5/CX_VFS_ERROR.
        rv_success = abap_false.
    ENDTRY.
  ENDMETHOD.

  METHOD GET_ITEM_ADO.
    " https://learn.microsoft.com/en-us/rest/api/azure/devops/git/items/get?view=azure-devops-rest-7.1&tabs=HTTP
    DATA lt_ret_data TYPE /ui5/cl_json_parser=>t_entry_map.
    DATA(itemPath) = |{ me->orgid }/_apis/git/repositories/{ me->repoid }/items?path={ iv_itempath }&includeContent=true&versionDescriptor.version={ iv_branch }&versionDescriptor.versionType=branch&api-version=7.1-preview.1|.
    DATA lv_status TYPE i.
    ev_content = ''.
    me->HTTP_GET_JSON(
        EXPORTING
            iv_path = itemPath
            iv_username = me->username
            iv_pat = me->pat
        IMPORTING
            ev_status = lv_status
            et_entry_map = lt_ret_data
             ).
    rv_success = abap_true.
    IF lv_status < 200 OR lv_status >= 300.
        me->write_telemetry( iv_message = |GET_ITEM_ADO fails to get item content from Git for branch { iv_branch }, path { iv_itempath }| ).
        rv_success = abap_false.
        EXIT.
    ENDIF.
    ev_content = lt_ret_data[ name = 'content' ]-value.
  ENDMETHOD.

  METHOD GET_COMMIT_ADO.
    " https://learn.microsoft.com/en-us/rest/api/azure/devops/git/commits/get?view=azure-devops-rest-7.1&tabs=HTTP
    DATA lt_ret_data TYPE /ui5/cl_json_parser=>t_entry_map.
    DATA(commitPath) = |{ me->orgid }/_apis/git/repositories/{ me->repoid }/commits?searchCriteria.$top=1&searchCriteria.itemVersion.version={ iv_branch }&api-version=7.1-preview.1|.
    DATA lv_status TYPE i.
    ev_commitid = ''.
    me->HTTP_GET_JSON(
        EXPORTING
            iv_path = commitPath
            iv_username = me->username
            iv_pat = me->pat
        IMPORTING
            ev_status = lv_status
            et_entry_map = lt_ret_data
             ).
    rv_success = abap_true.
    IF lv_status < 200 OR lv_status >= 300.
        me->write_telemetry( iv_message = |GET_COMMIT_ADO fails to get commit from Git for branch { iv_branch }| ).
        rv_success = abap_false.
        EXIT.
    ENDIF.
    ev_commitId = lt_ret_data[ name = 'commitId' parent = '/value/1' ]-value.
  ENDMETHOD.

  METHOD BUILD_PUSH_JSON.
    " https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pushes/create?view=azure-devops-rest-7.1&tabs=HTTP
    DATA lv_change TYPE ts_change.
    lv_change-changetype = iv_changetype.
    lv_change-item-path = iv_filename.
    " an add or edit should have file content prepared, but not for deletion
    IF iv_changetype <> 16.
        lv_change-newContent-content = iv_filecontent.
        lv_change-newContent-contentType = 0.
    ENDIF.
    APPEND lv_change TO iv_commit-changes.
  ENDMETHOD.

  METHOD PUSH_ADO.
    " https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pushes/create?view=azure-devops-rest-7.1&tabs=HTTP
    DATA(lv_branch) = |{ c_head }{ iv_branch }|.
    DATA(createPushPath) = |{ me->orgid }/_apis/git/repositories/{ me->repoid }/pushes?api-version=7.1-preview.2|.
    DATA lv_json_req TYPE ts_push_json_req.
    DATA lv_status TYPE i.
    DATA lt_ret_data TYPE /ui5/cl_json_parser=>t_entry_map.
    APPEND iv_commit TO lv_json_req-commits.
    APPEND VALUE ts_refupdate( name = lv_branch oldObjectId = iv_commitid ) TO lv_json_req-refUpdates.
    me->HTTP_POST_JSON(
        EXPORTING
            iv_path = createPushPath
            iv_username = me->username
            iv_pat = me->pat
            iv_json = lv_json_req
        IMPORTING
            ev_status = lv_status
            et_entry_map = lt_ret_data
             ).
    rv_success = abap_true.
    IF lv_status < 200 OR lv_status >= 300.
        me->write_telemetry( iv_message = |PUSH_ADO fails to push to Git for branch { lv_branch } on top of commit { iv_commitid }| ).
        rv_success = abap_false.
    ENDIF.
    ev_commitId = lt_ret_data[ name = 'newObjectId' parent = '/refUpdates/1' ]-value.
  ENDMETHOD.

  METHOD CREATE_HTTP_CLIENT.

    DATA  lo_http_client TYPE REF TO if_http_client.
    DATA lo_rest_client TYPE REF TO cl_rest_http_client.

    cl_http_client=>create_by_url(
        EXPORTING
            url                = iv_url
        IMPORTING
            client             = lo_http_client
        EXCEPTIONS
            argument_not_found = 1
            plugin_not_active  = 2
            internal_error     = 3
        OTHERS             = 4 ).

    " basic auth with user name and password (personal access token) for ADO REST APIs
    DATA(lv_auth) = cl_http_utility=>encode_base64( |{ iv_username }:{ iv_pat }| ).
    lv_auth = |Basic { lv_auth }|.
    lo_http_client->request->set_header_field( name = 'authorization' value = lv_auth ).
    lo_http_client->request->set_header_field( name = 'Accept' value = if_rest_media_type=>gc_appl_json ).
    lo_http_client->propertytype_logon_popup = lo_http_client->co_disabled.
    lo_http_client->request->set_version( if_http_request=>co_protocol_version_1_1 ).

    CREATE OBJECT lo_rest_client EXPORTING io_http_client = lo_http_client.

    DATA(lo_request) = lo_rest_client->if_rest_client~create_request_entity( ).
    lo_request->set_content_type( iv_media_type = if_rest_media_type=>gc_appl_json ).

    ei_http_client = lo_http_client.
    eo_rest_client = lo_rest_client.
    ei_request = lo_request.

  ENDMETHOD.

  METHOD HTTP_GET.
    io_rest_client->if_rest_resource~get( ).
    DATA(lo_response) = io_rest_client->if_rest_client~get_response_entity( ).
    ev_status = lo_response->get_header_field( '~status_code' ).
    ev_response = lo_response->get_string_data( ).
  ENDMETHOD.

  METHOD HTTP_POST.
    ii_request->set_string_data( iv_body ).
    io_rest_client->if_rest_resource~post( ii_request ).
    DATA(lo_response) = io_rest_client->if_rest_client~get_response_entity( ).
    ev_status = lo_response->get_header_field( '~status_code' ).
    ev_response = lo_response->get_string_data( ).
  ENDMETHOD.

  METHOD HTTP_GET_JSON.

    DATA li_http_client TYPE REF TO if_http_client.
    DATA lo_rest_client TYPE REF TO cl_rest_http_client.
    DATA li_request TYPE REF TO IF_REST_ENTITY.
    DATA(lv_url) = |{ c_host }{ iv_path }|.
    DATA lv_status TYPE string.
    DATA lv_response TYPE string.
    DATA lo_parse TYPE REF TO /ui5/cl_json_parser.
    DATA lv_statuscode TYPE i.

    me->create_http_client(
        EXPORTING
            iv_url = lv_url
            iv_username = iv_username
            iv_pat = iv_pat
        IMPORTING
            ei_http_client = li_http_client
            eo_rest_client = lo_rest_client
            ei_request = li_request
            ).

    me->http_get(
        EXPORTING
            io_rest_client = lo_rest_client
        IMPORTING
            ev_status = lv_status
            ev_response = lv_response
            ).
    lo_rest_client->if_rest_client~close( ).

    lv_statuscode = lv_status.

    IF et_entry_map IS SUPPLIED.
        CLEAR et_entry_map.
    ENDIF.

    IF ev_status IS SUPPLIED.
        ev_status = lv_statuscode.
    ENDIF.

    IF lv_statuscode < 200 OR lv_statuscode >= 300.
        me->write_telemetry( iv_message = |HTTP_GET_JSON HTTP GET for { lv_url } status code { lv_status }, response { lv_response }| ).
        EXIT.
    ENDIF.

    IF et_entry_map IS SUPPLIED.
        CREATE OBJECT lo_parse.
        lo_parse->parse( json = lv_response ).
        et_entry_map = lo_parse->m_entries.
    ENDIF.

  ENDMETHOD.

  METHOD HTTP_POST_JSON.

    DATA lr_json_serializer TYPE REF TO cl_trex_json_serializer.
    DATA li_http_client TYPE REF TO if_http_client.
    DATA lo_rest_client TYPE REF TO cl_rest_http_client.
    DATA li_request TYPE REF TO IF_REST_ENTITY.
    DATA(lv_url) = |{ c_host }{ iv_path }|.
    DATA lv_status TYPE string.
    DATA lv_response TYPE string.
    DATA lo_parse TYPE REF TO /ui5/cl_json_parser.
    DATA lv_statuscode TYPE i.

    CREATE OBJECT lr_json_serializer EXPORTING data = iv_json.
    lr_json_serializer->serialize( ).
    DATA(lv_body) = lr_json_serializer->get_data( ).

    me->create_http_client(
        EXPORTING
            iv_url = lv_url
            iv_username = iv_username
            iv_pat = iv_pat
        IMPORTING
            ei_http_client = li_http_client
            eo_rest_client = lo_rest_client
            ei_request = li_request
            ).

    me->http_post(
        EXPORTING
            io_rest_client = lo_rest_client
            ii_request = li_request
            iv_body = lv_body
        IMPORTING
            ev_status = lv_status
            ev_response = lv_response
            ).
    lo_rest_client->if_rest_client~close( ).

    lv_statuscode = lv_status.

    IF ev_status IS SUPPLIED.
        ev_status = lv_statuscode.
    ENDIF.

    IF et_entry_map IS SUPPLIED.
        CLEAR et_entry_map.
    ENDIF.

    IF lv_statuscode < 200 OR lv_statuscode >= 300.
        me->write_telemetry( iv_message = |HTTP_POST_JSON HTTP POST for { lv_url } status code { lv_status }, response { lv_response }| ).
        EXIT.
    ENDIF.

    IF et_entry_map IS SUPPLIED.
        CREATE OBJECT lo_parse.
        lo_parse->parse( json = lv_response ).
        et_entry_map = lo_parse->m_entries.
    ENDIF.

  ENDMETHOD.

  METHOD WRITE_TELEMETRY.
    IF me->oref_telemetry IS NOT INITIAL AND me->method_name_telemetry IS NOT INITIAL.
        DATA(oref) = me->oref_telemetry.
        DATA(meth) = me->method_name_telemetry.
        CALL METHOD oref->(meth)
            EXPORTING
                iv_message = iv_message
                iv_kind = iv_kind.
    ELSE.
        WRITE / |{ iv_kind }: { iv_message }|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.