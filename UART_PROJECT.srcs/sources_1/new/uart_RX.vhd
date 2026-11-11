library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_RX is
    generic (CLKS_PER_BIT : natural := 16);
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;                      -- active low reset
        rx_ready : in std_logic;                      -- high when idle (waiting for a start bit)
        rx_valid : out std_logic;                      -- high for 1 clock when rx_data is a new byte
        rx_data  : out std_logic_vector(7 downto 0);
        rx       : in  std_logic
    );
end entity;

architecture rtl of uart_RX is
    type state_t is (S_IDLE, S_RX_START, S_RX_DATA, S_RX_STOP);

    constant HALF_BIT : natural := CLKS_PER_BIT / 2;

    signal state       : state_t := S_IDLE;
    signal clk_count   : natural range 0 to CLKS_PER_BIT-1 := HALF_BIT-1;
    signal bit_index   : natural range 0 to 7 := 7;
    signal rx_data_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_sync1    : std_logic := '1';
    signal rx_sync2    : std_logic := '1';

    signal next_state     : state_t;
    signal next_clk_count : natural range 0 to CLKS_PER_BIT-1;
    signal next_bit_index : natural range 0 to 7;
begin

    -- Baud counter: in idle preload half a bit (to reach the middle of the start bit),
    -- afterwards reload a full bit period each time it reaches 0
    next_clk_count <= HALF_BIT-1     when (state = S_IDLE) else
                      CLKS_PER_BIT-1 when (clk_count = 0)  else
                      clk_count - 1;

    -- State transitions (hold state otherwise)
    next_state <= S_RX_START when (state = S_IDLE     and rx_sync2 = '0')                          else
                  S_RX_DATA  when (state = S_RX_START and clk_count = 0 and rx_sync2 = '0')        else
                  S_IDLE     when (state = S_RX_START and clk_count = 0 and rx_sync2 = '1')        else  -- glitch
                  S_RX_STOP  when (state = S_RX_DATA  and clk_count = 0 and bit_index = 0)         else
                  S_IDLE     when (state = S_RX_STOP  and clk_count = 0)                           else
                  state;

    -- Bit counter: increments after each sampled data bit, cleared outside S_RX_DATA
    next_bit_index <= bit_index - 1 when (state = S_RX_DATA and clk_count = 0 and bit_index /= 0) else
                      7             when (state /= S_RX_DATA) else
                      bit_index;

    

    -- Output the received byte; valid pulse at the middle of a good stop bit
    rx_data  <= rx_data_reg;
    rx_valid <= '1' when (state = S_RX_STOP and clk_count = 0 and rx_sync2 = '1') else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            -- 2-FF synchronizer for the asynchronous rx input
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;

            if rst_n = '0' then
                state       <= S_IDLE;
                clk_count   <= HALF_BIT-1;
                bit_index   <= 7;
                rx_data_reg <= (others => '0');
            else
                state     <= next_state;
                clk_count <= next_clk_count;
                bit_index <= next_bit_index;

                -- sample in the middle of each data bit, LSB first
                if state = S_RX_DATA and clk_count = 0 then
                    rx_data_reg(7-bit_index) <= rx_sync2;
                end if;
            end if;
        end if;
    end process;
end architecture;