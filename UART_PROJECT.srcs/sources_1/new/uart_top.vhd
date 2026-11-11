library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity uart_top is
    generic (CLKS_PER_BIT : natural := 16);
    Port ( 
            clk : in std_logic ;
            rst_n : in std_logic ;
            
            --salve data 
            s_axis_tdata : in std_logic_vector(7 downto 0);
            s_axis_tvalid : in std_logic;
            s_axis_tready : out std_logic ;
            
            --master data 
            m_axis_tdata : out std_logic_vector(7 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in std_logic ;
            
            --
            tx : out std_logic ;
            rx : in std_logic 
     );
end uart_top;

architecture Behavioral of uart_top is

signal FIFO_TX_tdata, FIFO_RX_tdata : std_logic_vector (7 downto 0);
signal FIFO_TX_tvalid,FIFO_RX_tvalid : std_logic ;
signal FIFO_TX_tready,FIFO_RX_tready : std_logic ;
signal TX_START : std_logic;


begin

TX_START <= FIFO_TX_tvalid and FIFO_TX_tready;

TX_FIFO : entity work.axis_data_fifo_0
 port map (
    s_axis_aclk => clk,
    s_axis_aresetn => rst_n,
    s_axis_tdata => s_axis_tdata,
    s_axis_tvalid => s_axis_tvalid,
    s_axis_tready => s_axis_tready,
    
    m_axis_tdata => FIFO_TX_tdata,
    m_axis_tvalid => FIFO_TX_tvalid,
    m_axis_tready => FIFO_TX_tready,
    
    axis_wr_data_count => open,
    axis_rd_data_count =>open,
    almost_full => open,
    almost_empty => open
 );
 
 
TX_UART : entity work.uart_TX

generic map( CLKS_PER_BIT => CLKS_PER_BIT)
port map (
    
    clk => clk,
    rst_n => rst_n,
    tx_ready => FIFO_TX_tready,
    tx_start=> TX_START,
    tx_data =>  FIFO_TX_tdata,
    tx => tx );
    
    
RX_UART : entity work.uart_RX
generic map( CLKS_PER_BIT => CLKS_PER_BIT)
port map(
    clk=> clk,
    rst_n => rst_n,
    rx_ready => FIFO_RX_tready,
    rx_valid => FIFO_RX_tvalid,
    rx_data => FIFO_RX_tdata,
    rx=> rx);

RX_FIFO : entity work.axis_data_fifo_0

 port map (
    s_axis_aclk => clk,
    s_axis_aresetn => rst_n,
    s_axis_tdata => FIFO_RX_tdata,
    s_axis_tvalid => FIFO_RX_tvalid,
    s_axis_tready => FIFO_RX_tready,
    
    m_axis_tdata => m_axis_tdata,
    m_axis_tvalid => m_axis_tvalid,
    m_axis_tready => m_axis_tready,
    
    axis_wr_data_count => open,
    axis_rd_data_count =>open,
    almost_full => open,
    almost_empty => open
 );   
   


end Behavioral;
