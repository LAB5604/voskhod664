#include "sd_spi.h"

//*******************************************************************************
//* Function Name  : SD_SPI_WriteByte
//* Description    : 发�?�一个数�? 
//* Input          : byte : byte to send.
//* Output         : None
//* Return         : None
//*******************************************************************************/
void SD_SPI_WriteByte(uint8_t byte)
{
	//uint32_t writebyte = byte;
	//HAL_SPIM_Write_Polling(&writebyte, 1);
  Spi_sendbyte(SD_SPI,byte);
}

//*******************************************************************************
//* Function Name  : SD_SPI_ReadByte
//* Description    : 发�?�一个数�? 
//* Input          : None
//* Output         : None
//* Return         : 返回接收到的字节
//*******************************************************************************/
uint8_t SD_SPI_ReadByte()
{
	uint8_t recv_byte;
	//HAL_SPIM_Read_Only_Polling(&recv_byte,1); 
  Spi_sendbyte(SD_SPI,0xFF);
	return Spi_recvbyte(SD_SPI);
}

 
/*******************************************************************************
* 函数名称       : SD_Select
* 功能描述       : 选择SD卡，并等待SD卡准备好
* 进入参数       : �?.
* 返回参数       : 0：成�?       1：失�?
* 备注说明       : SD卡准备好会返�?0XFF
*******************************************************************************/
uint8_t SD_Select(void)
{
    uint32_t t=0;
    uint8_t  res=0;
    SPI_CS_LOW;//片�?�SD，低电平使能
 
    do
    {
        if(SD_SPI_ReadByte()==0XFF)
        {        
            res = 1;//OK
            break;
        }
        t++;     
    }while(t<0XFFFFFF);//等待
    SPI_CS_HIGH;//SD_DisSelect();  //释放总线
   
    return res;//等待失败
}
//取消选择,释放SPI总线  
void SD_DisSelect(void)  
{  
    SPI_CS_HIGH;  
    uint32_t send_byte =0xFF;
    //SPI_CS_HIGH;         
    //HAL_SPIM_Write_Polling(&send_byte, 1);//提供额外�?8个时�?    
    SD_SPI_WriteByte(0x00);
} 
///*******************************************************************************
//* 函数名称       : SD_SendCmd
//* 功能描述       : 向sd卡写入一个数据包的内�? 512字节
//* 进入参数       : cmd：命�?  arg：命令参�?  crc：crc校验值及停止�?
//* 返回参数       : 返回�?:SD卡返回的对应相应命令的响�?
//* 备注说明       : 响应为R1-R7，见SD协议手册V2.0版（2006�?
//*******************************************************************************/
uint8_t SD_SendCmd(uint8_t cmd, uint32_t arg, uint8_t crc, uint8_t reset)
{
    uint8_t tmp; 
    uint8_t i  ; 
    //SD_DisSelect();
    SPI_CS_LOW;
    
    SD_SPI_WriteByte(cmd | 0x40);//分别写入命令
    //SEGGER_RTT_printf(0,"SD_SPI_ReadWriteByte(cmd | 0x40)\n");     
	//}
    SD_SPI_WriteByte(arg >> 24);
    SD_SPI_WriteByte(arg >> 16);
    SD_SPI_WriteByte(arg >> 8);
    SD_SPI_WriteByte(arg);   
    SD_SPI_WriteByte(crc); 


    i=0; //成功或超时�??�?
    do
    {
        tmp=SD_SPI_ReadByte();
        i++;        
        if(i>200)
            break;
    }while(tmp==0xff);   
    return tmp;
}

uint8_t Sdcard_init()//Spi_Reg *reg
{
    uint8_t r1;      // 存放SD卡的返回�?
    uint16_t tmp;  // 用来进行超时计数
    uint8_t  buf[4];  
    uint16_t i;
    uint32_t send_pulse[10];   
#ifdef DEBUG_OUTPUT 
    anl_printf(0,"Test SD Card by SPI Mode... ...\n"); 
#endif
    SPI_CS_HIGH;//Send 74 pulse
    for(i=0;i<9;i++)
        Spi_sendbyte(SD_SPI,0xff);
    SPI_CS_HIGH;

    i=0;
    do
    {   //发�?�CMD0,进入SPI模式
        tmp = SD_SendCmd(0,0,0x95,1);
        i++;
    }while((tmp!=0x01)&&(i<200));//等待回应0x01

    if(tmp==200)
        return 1; //失败�?�?

  	//获取卡的版本信息
    SPI_CS_LOW; 
	tmp=SD_SendCmd(8, 0x1aa,0x87,0);
#ifdef DEBUG_OUTPUT 
	anl_printf("SD 1Ver. %d\r\n",tmp);
#endif
    if(tmp==0x05)
    {   //v1.0版和MMC
        SD_Type=V1;  //预设SDV1.0
    
        SPI_CS_HIGH;    
        
        SD_SPI_WriteByte(0xff); //增加8个时钟确保本次操作完�?
    
        i=0;
        do
        {
            tmp=SD_SendCmd(55,0,0,1); //发�?�CMD55,应返�?0x01
            if(tmp==0xff)
                return tmp;  //返回0xff表明无卡,�?�?
        
            tmp=SD_SendCmd(41,0,0,1); //再发送CMD41,应返�?0x00
            i++;
            //回应正确,则卡类型预设成立
        }while((tmp!=0x00) && (i<400));
    
        if(i==400)
        {   //无回�?,是MMC�?
            i=0;
            
            do
            {   //MMC卡初始化
                tmp=SD_SendCmd(1,0,0,1);
                i++;
            }while((tmp!=0x00)&& (i<400));

        if(i==400)
            return 1;   //MMC卡初始化失败
            
        SD_Type=MMC;
    }
    
    //SPI1_Init(4); //SPI时钟改用4分频(18MHz)

    SD_SPI_WriteByte(0xff);//输出8个时钟确保前次操作结�?

    //禁用CRC校验
    tmp=SD_SendCmd(59,0,0x95,1);
    if(tmp!=0x00)
      return tmp;  //错误返回
    
    //设置扇区宽度
    tmp=SD_SendCmd(16,512,0x95,1);
    if(tmp!=0x00)
        return tmp;//错误返回
  	}
  	
  	else if(tmp==0x01)
  	{ //V2.0和V2.0HC�?
    //忽略V2.0卡的后续4字节
    SD_SPI_WriteByte(0xff);
    SD_SPI_WriteByte(0xff);
    SD_SPI_WriteByte(0xff);
    SD_SPI_WriteByte(0xff);
        
    SPI_CS_HIGH;        
    SD_SPI_WriteByte(0xff); //增加8个时钟确保本次操作完�?
        
    {     
      i=0;
      do
      {
        tmp=SD_SendCmd(55,0,0,1);
        if(tmp!=0x01)
          return tmp;    //错误返回  
        
        tmp=SD_SendCmd(41,0x40000000,0,1);
        if(i>200)
          return tmp;  //超时返回
      }while(tmp!=0);         

      tmp=SD_SendCmd(58,0,0,0);
      if(tmp!=0x00)
      {
        //SD_CS=1;  //失能SD
        SPI_CS_HIGH;      
        return tmp;  //错误返回
      }
      
      //接收OCR信息
      SD_SPI_WriteByte(0xff);
      buf[0]=SD_SPI_ReadByte();
      SD_SPI_WriteByte(0xff);
      buf[1]=SD_SPI_ReadByte();      
      SD_SPI_WriteByte(0xff);
      buf[2]=SD_SPI_ReadByte();    
      SD_SPI_WriteByte(0xff);
      buf[3]=SD_SPI_ReadByte();    
                  
      SPI_CS_HIGH;  
      SD_SPI_WriteByte(0xff); //增加8个时钟确保本次操作完�?

      if(buf[0]&0x40)
        SD_Type=V2HC;
      else 
        SD_Type=V2;     

      //SPI1_Init(4);
    }       
  }
#ifdef DEBUG_OUTPUT 
	anl_printf("SD SD_Type. %d\r\n",SD_Type);      
#endif
  return tmp;    
      
} 
/////////////////////////////////////////////////////////////////////////////
//---------------------------------------------------------------------------------------------------------
//读SD卡应答并判断
//response:正确回应�?
//成功返回0,失败返回1
uint8_t SD_GetResponse(uint8_t response)
{
  uint16_t ii; 
  uint8_t recv_val=0;
  ii=5000; //读应答最�?5000�?
	//SPI_CS_LOW; 
  while(ii)
  {
  	//SD_SPI_WriteByte(0xFF);
  	 
	recv_val = SD_SPI_ReadByte();
  	if(recv_val == response)
  		break;
	ii--;
  }
 //SPI_CS_HIGH;
	//SEGGER_RTT_printf(0,"SD SD_GetResponse. %d~\n",ii);        
  if (ii==0)
    return 1;//返回失败
  else 
    return 0;//返回成功
}

//从sd卡读取一个数据包的内�?  
//buf:数据缓存�?  
//len:要读取的数据长度.  
//返回�?:0,成功;其他,失败;  
//0XFE数据起始令牌      
uint8_t SdRecvData(uint8_t *buf,uint16_t len)  
{
	SPI_CS_LOW;     
    uint16_t i;     
    if(SD_GetResponse(0xFE))
    {
    	SPI_CS_HIGH;  	
		return 1;//等待SD卡发回数据起始令�?0xFE 
	}
 
 	for(i=0; i<len; i++)
    //while(len--)//�?始接收数�?  
    {  
   
        *buf=SD_SPI_ReadByte();//SdSpiReadWriteByte(0xFF);  
        buf++;  
    }  
  
    SD_SPI_ReadByte();
    SD_SPI_ReadByte();   
    	SPI_CS_HIGH;                                                             
    return 0;//读取成功  
}  

//////////////////////////////////////////////////////////////////////////////
//读SD�?  
//buf:数据缓存�?  
//sector:扇区  
//cnt:扇区�?  
//返回�?:0,ok;其他,失败.  
uint8_t SDReadSector(uint8_t *buf,uint32_t sector)  
{  
    uint8_t r1;  
  	if(SD_Type!=V2HC) sector = sector<<9;    	
    SPI_CS_LOW; 
    r1=SD_SendCmd(17,sector,0x01,1);//读命�?    
    
    if(r1==0)//指令发�?�成�?  
    {  
      #ifdef DEBUG_OUTPUT 
        anl_printf("SD_CMD OK\r\n");
      #endif
        r1=SdRecvData(buf,512);//接收512个字�?        
    }  
    SD_DisSelect();//取消片�??  
    return r1;//  
}  


//向sd卡写入一个数据包的内�? 512字节  
//buf:数据缓存�?  
//cmd:指令  
//返回�?:0,成功;其他,失败;     
uint8_t SD_SendBlock(uint8_t*buf,uint8_t cmd)  
{     
    uint16_t t;              
    //if(SdWaitReady())return 1;//等待准备失效  
    SD_SPI_WriteByte(cmd);  
    if(cmd!=0XFD)//不是结束指令  
    {  
        for(t=0;t<512;t++)SD_SPI_WriteByte(buf[t]);//提高速度,减少函数传参时间  
        SD_SPI_WriteByte(0xFF);//忽略crc  
        SD_SPI_WriteByte(0xFF);  
        t=SD_SPI_ReadByte();//接收响应  
        if((t&0x1F)!=0x05)return 2;//响应错误                                                             
    }                                                                                     
    return 0;//写入成功  
}  

//写SD�?  
//buf:数据缓存�?  
//sector:起始扇区  
//cnt:扇区�?  
//返回�?:0,ok;其他,失败.  
uint8_t SDWriteSector(uint8_t *buf,uint32_t sector)  
{  
    uint8_t r1;  
    if(SD_Type!= V2HC)sector = sector << 9;//转换为字节地�?  
    SPI_CS_LOW; 
    r1=SD_SendCmd(CMD24,sector,0X01,1);//读命�?  
    if(r1==0)//指令发�?�成�?  
    {  
        r1=SD_SendBlock(buf,0xFE);//�?512个字�?       
    }  
    SD_DisSelect();//取消片�??  
    return r1;//  
}  

