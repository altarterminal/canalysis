#include <stdio.h>

int func_innertop(void);
int func_innermiddle(void);
int func_innerbottom(void);
extern int func_outer(void);

static int val_inner_static;
int val_inner_global;
extern int val_outer_global;

int main(void)
{
  int x = func_innertop();
  
  return 0;
}

int func_innertop()
{
  return func_innermiddle() + func_outer() + val_outer_global;
}

int func_innermiddle()
{
  return func_innerbottom() + val_inner_global;
}

int func_innerbottom()
{
  return val_inner_static;
}
