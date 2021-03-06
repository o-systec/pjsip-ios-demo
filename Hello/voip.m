//
//  demo.m
//  Hello
//
//  Created by bluefish on 2019/7/5.
//  Copyright © 2019 systec. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "Hello-Swift.h"

#import <pjsua.h>

#define THIS_FILE "voip"

enum {
    VOIP_INVALID_ID = -1,
};

typedef struct Voip_t {
    pjsua_acc_id acc_id;
    pjsua_call_id call_id;
    pjsua_call_id call_id_out;
    pjsua_transport_id utid;
} Voip_t;

static Voip_t *self;

static void change_ui_status(const char *data) {
    __block NSString *label = [[NSString alloc] initWithUTF8String: data];
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_async(queue, ^{
        [VoipManager sendMessage: 0 data: label];
    });
}

static void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata) {
    pjsua_call_info ci;
    
    PJ_UNUSED_ARG(acc_id);
    PJ_UNUSED_ARG(rdata);
    
    pjsua_call_get_info(call_id, &ci);
    
    PJ_LOG(3,(THIS_FILE, "Incoming call from %.*s!!", (int)ci.remote_info.slen, ci.remote_info.ptr));
    
    /* Automatically answer incoming calls with 200/OK */
//    pjsua_call_answer(call_id, 200, NULL, NULL);
    
    
    if(VOIP_INVALID_ID == self->call_id && VOIP_INVALID_ID == self->call_id_out) {
        AudioServicesPlaySystemSound(1109); /* shake */
        self->call_id = call_id;
        pjsua_call_answer(call_id, 180 /* ring */, NULL, NULL);
    }
    
    change_ui_status(ci.remote_info.ptr);
}

/* Callback called by the library when call's state has changed */
static void on_call_state(pjsua_call_id call_id, pjsip_event *e) {
    pjsua_call_info ci;
    
    PJ_UNUSED_ARG(e);
    
    pjsua_call_get_info(call_id, &ci);
    PJ_LOG(3,(THIS_FILE, "Call %d state=%.*s", call_id, (int)ci.state_text.slen, ci.state_text.ptr));
    
//    char buf[512] = "";
//    sprintf(buf, "Call %d state=%.*s", (int)ci.state_text.slen, ci.state_text.ptr);
    if(PJSIP_INV_STATE_DISCONNECTED == ci.state) {
        self->call_id = VOIP_INVALID_ID;
        self->call_id_out = VOIP_INVALID_ID;
    } else if (PJSIP_INV_STATE_EARLY == ci.state) {
        AudioServicesPlaySystemSound(1109);
    }
    change_ui_status(ci.state_text.ptr);
}

/* Callback called by the library when call's media state has changed */
static void on_call_media_state(pjsua_call_id call_id) {
    pjsua_call_info ci;
    
    pjsua_call_get_info(call_id, &ci);
    
    if (ci.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
        // When media is active, connect call to sound device.
        pjsua_conf_connect(ci.conf_slot, 0);
        pjsua_conf_connect(0, ci.conf_slot);
    }
}

static void on_reg_state(pjsua_acc_id acc_id) {
    pjsua_acc_info ai;
    pjsua_acc_get_info(acc_id, &ai);
    PJ_LOG(3,(THIS_FILE, "on_reg_state %d", ai.status));
    change_ui_status(ai.status_text.ptr);
}

int voip_account_update(const char *domain, const char *user, const char *passwd) {
    pj_status_t status;
    
    status = pjsua_transport_restart(self->utid, 0);
//    PJ_LOG(3,(THIS_FILE, "+++3 %u %u %u", status, PJ_EINVAL, PJ_SUCCESS));
    
    pjsua_acc_config cfg;
    pjsua_acc_config_default(&cfg);
    
    cfg.transport_id = self->utid;
    
    char sip_id[128] = "";
    sprintf(sip_id, "sip:%s@%s", user, domain);
    cfg.id = pj_str(sip_id);
    char uri[128] = "";
    sprintf(uri, "sip:%s", domain);
    cfg.reg_uri = pj_str(uri);
    cfg.cred_count = 1;
    cfg.cred_info[0].realm = pj_str("*");
    cfg.cred_info[0].scheme = pj_str("digest");
    cfg.cred_info[0].username = pj_str((char *)user);
    cfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    cfg.cred_info[0].data = pj_str((char *)passwd);
//    pjsua_acc_add(&cfg, PJ_TRUE, &acc_id);
    pjsua_acc_modify(self->acc_id, &cfg);
    status = pjsua_acc_set_registration(self->acc_id, 1);
//    pjsua_acc_set_online_status(acc_id, 1);
    if (status != PJ_SUCCESS) {
        PJ_LOG(3,(THIS_FILE, "registration %s error", sip_id));
    } else {
        PJ_LOG(3,(THIS_FILE, "registration %s ok", sip_id));
    }
    return 0;
}

int voip_account_unregister() {
    pj_status_t status;
    
//    status = pjsua_acc_set_registration(voip.acc_id, 0);
    
    pjsua_acc_config cfg;
    pjsua_acc_config_default(&cfg);
    
    const char *local_id = "sip:127.0.0.1";
    
    cfg.id = pj_str((char *)local_id); /* local account */
    status = pjsua_acc_modify(self->acc_id, &cfg);
    
    if (status != PJ_SUCCESS) {
        PJ_LOG(3,(THIS_FILE, "add account %s error", local_id));
    } else {
        PJ_LOG(3,(THIS_FILE, "add account %s ok", local_id));
    }
    return 0;
}

void voip_start(unsigned port) {
    self = calloc(1, sizeof(Voip_t));
    self->acc_id = VOIP_INVALID_ID;
    self->call_id = VOIP_INVALID_ID;
    self->call_id_out = VOIP_INVALID_ID;
    
    pj_status_t status;
    pjsua_transport_id utid;
    
    pjsua_create();
    
    pjsua_config ua_cfg;
    pjsua_logging_config log_cfg;
    pjsua_media_config media_cfg;
    
    pjsua_config_default(&ua_cfg);
    ua_cfg.cb.on_incoming_call = &on_incoming_call;
    ua_cfg.cb.on_call_media_state = &on_call_media_state;
    ua_cfg.cb.on_call_state = &on_call_state;
    ua_cfg.cb.on_reg_state = &on_reg_state;
    
    pjsua_logging_config_default(&log_cfg);
    log_cfg.console_level = 3; /* 3 better */
    pjsua_media_config_default(&media_cfg);
    
    pjsua_init(&ua_cfg, &log_cfg, &media_cfg);
    
    pjsua_transport_config transport_cfg;
    
    pjsua_transport_config_default(&transport_cfg);
    
    transport_cfg.port = port;
    
    
    pjsua_transport_create(PJSIP_TRANSPORT_UDP, &transport_cfg, &utid);
    // pjsua_transport_create(PJSIP_TRANSPORT_TCP, &transportConfig, NULL);
    self->utid = utid;
    
    pjsua_start();
    
    pjsua_acc_config cfg;
    
    pjsua_acc_config_default(&cfg);
    
    const char *local_id = "sip:127.0.0.1";
    
    cfg.id = pj_str((char *)local_id); /* local account */
    status = pjsua_acc_add(&cfg, PJ_TRUE, &self->acc_id);
    
    if (status != PJ_SUCCESS) {
        PJ_LOG(3,(THIS_FILE, "add account %s error", local_id));
    } else {
        PJ_LOG(3,(THIS_FILE, "add account %s ok", local_id));
    }
    
    pjsua_transport_info ti;
    pjsua_transport_get_info(utid, &ti);
    
    __block NSString *label = [[NSString alloc] initWithFormat:@"%s:%d", ti.local_name.host.ptr, ti.local_name.port];
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_async(queue, ^{
        [VoipManager sendMessage: 1 data: label];
    });
    
    PJ_LOG(3,(THIS_FILE, "published address is %s:%d", ti.local_name.host.ptr, ti.local_name.port));
}

void voip_hangup() {
    pjsua_call_hangup_all();
    self->call_id = VOIP_INVALID_ID;
    self->call_id_out = VOIP_INVALID_ID;
}

void voip_answer() {
    PJ_LOG(3,(THIS_FILE, "voip_answer %d", self->call_id));
    if(VOIP_INVALID_ID != self->call_id && VOIP_INVALID_ID == self->call_id_out) {
        pjsua_call_answer(self->call_id, 200, NULL, NULL);
    }
}

void voip_call(const char *uri) {
    if(VOIP_INVALID_ID != self->call_id_out || VOIP_INVALID_ID != self->call_id) {
        voip_hangup();
    }
    pjsua_call_id call_id;
    pj_status_t status;
    pj_str_t callee_uri = pj_str((char *)uri);
    status = pjsua_call_make_call(self->acc_id, &callee_uri, 0, NULL, NULL, &call_id);
    if (status != PJ_SUCCESS) {
        PJ_LOG(3,(THIS_FILE, "call %s error", uri));
    } else {
        self->call_id_out = call_id;
        PJ_LOG(3,(THIS_FILE, "call %s ok", uri));
    }
}
