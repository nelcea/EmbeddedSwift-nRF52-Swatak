//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors.
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#include <autoconf.h>

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>

#define LED1_NODE DT_ALIAS(led1)
static struct gpio_dt_spec led1 = GPIO_DT_SPEC_GET(LED1_NODE, gpios);
#define LED2_NODE DT_ALIAS(led2)
static struct gpio_dt_spec led2 = GPIO_DT_SPEC_GET(LED2_NODE, gpios);
#define LED3_NODE DT_ALIAS(led3)
static struct gpio_dt_spec led3 = GPIO_DT_SPEC_GET(LED3_NODE, gpios);
#define LED4_NODE DT_ALIAS(led4)
static struct gpio_dt_spec led4 = GPIO_DT_SPEC_GET(LED4_NODE, gpios);
#define LED5_NODE DT_ALIAS(led5)
static struct gpio_dt_spec led5 = GPIO_DT_SPEC_GET(LED5_NODE, gpios);

#define BUTTON1_NODE DT_ALIAS(button1)
static struct gpio_dt_spec button1 = GPIO_DT_SPEC_GET(BUTTON1_NODE, gpios);
#define BUTTON2_NODE DT_ALIAS(button2)
static struct gpio_dt_spec button2 = GPIO_DT_SPEC_GET(BUTTON2_NODE, gpios);
#define BUTTON3_NODE DT_ALIAS(button3)
static struct gpio_dt_spec button3 = GPIO_DT_SPEC_GET(BUTTON3_NODE, gpios);
#define BUTTON4_NODE DT_ALIAS(button4)
static struct gpio_dt_spec button4 = GPIO_DT_SPEC_GET(BUTTON4_NODE, gpios);
#define BUTTON5_NODE DT_ALIAS(button5)
static struct gpio_dt_spec button5 = GPIO_DT_SPEC_GET(BUTTON5_NODE, gpios);

struct extended_callback {
	struct gpio_callback pin_cb_data;
    void *context;
};

static inline struct extended_callback *container_of(struct gpio_callback *ptr)
{
    return ((struct extended_callback *)(((char *)(ptr)) - offsetof(struct extended_callback, pin_cb_data)));
}