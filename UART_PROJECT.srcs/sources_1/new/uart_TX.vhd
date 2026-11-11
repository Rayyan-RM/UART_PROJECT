library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_TX is
    generic (CLKS_PER_BIT : natural := 16);
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;  -- active low reset
        tx_ready : out std_logic;  -- high when ready for a new byte
        tx_start : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        tx       : out std_logic
    );
end entity;

architecture rtl of uart_TX is
    type state_t is (S_IDLE, S_TX_START, S_TX_DATA, S_TX_STOP);

    signal state     : state_t := S_IDLE;
    signal clk_count : natural range 0 to CLKS_PER_BIT-1 := CLKS_PER_BIT-1;
    signal bit_index : natural range 0 to 7 := 7;
    signal tx_data_reg : std_logic_vector(7 downto 0) := (others => '0');

    signal next_state     : state_t;
    signal next_clk_count : natural range 0 to CLKS_PER_BIT-1;
    signal next_bit_index : natural range 0 to 7;
begin

    -- Baud counter: reload in idle or when a bit period ends
    next_clk_count <= CLKS_PER_BIT-1 when (state = S_IDLE or clk_count = 0)
                      else clk_count - 1;

    -- State transitions (hold state otherwise)
    next_state <= S_TX_START when (state = S_IDLE     and tx_start = '1') else
                  S_TX_DATA  when (state = S_TX_START and clk_count = 0)  else
                  S_TX_STOP  when (state = S_TX_DATA  and clk_count = 0 and bit_index = 0) else
                  S_IDLE     when (state = S_TX_STOP  and clk_count = 0)  else
                  state;

    -- Bit counter: increments at the end of each data bit, cleared outside S_TX_DATA
    next_bit_index <= bit_index - 1 when (state = S_TX_DATA and clk_count = 0 and bit_index /= 0) else
                      7             when (state /= S_TX_DATA) else
                      bit_index;

    tx_ready <= '1' when state = S_IDLE else '0';

    -- Output (LSB first), single driver
    tx <= '0'                when state = S_TX_START else
          tx_data_reg(7-bit_index) when state = S_TX_DATA  else
          '1';  -- idle and stop

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state       <= S_IDLE;
                clk_count   <= CLKS_PER_BIT-1;
                bit_index   <= 7;
                tx_data_reg <= (others => '0');
            else
                state     <= next_state;
                clk_count <= next_clk_count;
                bit_index <= next_bit_index;

                if state = S_IDLE and tx_start = '1' then
                    tx_data_reg <= tx_data;
                end if;
            end if;
        end if;
    end process;
end architecture;