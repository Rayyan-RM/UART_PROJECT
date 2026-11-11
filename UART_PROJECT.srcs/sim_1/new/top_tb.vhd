
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_top is
end tb_uart_top;

architecture sim of tb_uart_top is

    constant CLK_PERIOD : time := 10 ns;
    constant CLKS_PER_BIT : natural := 16;

    signal clk   : std_logic := '0';
    signal rst_n : std_logic := '0';

    signal s_axis_tdata  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal m_axis_tdata  : std_logic_vector(7 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '0';

    signal tx : std_logic;
    signal rx : std_logic;

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- Loopback connection
    rx <= tx;

    -- DUT
    DUT : entity work.uart_top
        generic map (
            CLKS_PER_BIT => CLKS_PER_BIT
        )
        port map (
            clk => clk,
            rst_n => rst_n,

            s_axis_tdata => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,

            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,

            tx => tx,
            rx => rx
        );

    -- Test process
    stimulus : process
        type data_array is array (natural range <>) of
            std_logic_vector(7 downto 0);

        constant test_data : data_array :=
            (x"55", x"A3", x"12", x"FF", x"00");

    begin

        -- Reset
        rst_n <= '0';
        wait for 20 * CLK_PERIOD;
        wait until rising_edge(clk);
        rst_n <= '1';

        wait for 5 * CLK_PERIOD;

        -- Enable output FIFO reading
        m_axis_tready <= '1';

        -- Send test data
        for i in test_data'range loop

            wait until rising_edge(clk);

            s_axis_tdata <= test_data(i);
            s_axis_tvalid <= '1';

            -- Wait for AXI input handshake
            loop
                wait until rising_edge(clk);
                exit when s_axis_tready = '1';
            end loop;

            s_axis_tvalid <= '0';

            -- Wait for returned data
            loop
                wait until rising_edge(clk);
                exit when m_axis_tvalid = '1';
            end loop;

            -- Compare output
            assert m_axis_tdata = test_data(i)
                report "LOOPBACK ERROR: Data mismatch!"
                severity error;

            report "LOOPBACK PASS: Received byte = " &
                integer'image(to_integer(unsigned(m_axis_tdata)));

        end loop;

        report "ALL UART LOOPBACK TESTS PASSED!"
            severity note;

        wait;

    end process;

end sim;
