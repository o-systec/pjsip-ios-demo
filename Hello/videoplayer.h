//
//  videoplayer.h
//  Hello
//
//  Created by bluefish on 2019/7/6.
//  Copyright © 2019 systec. All rights reserved.
//

#ifndef videoplayer_h
#define videoplayer_h

#import <UIKit/UIKit.h>

void *videoplayer_play(UIImageView *view, const char *uri);
void videoplayer_stop(void *player);

#endif /* videoplayer_h */
